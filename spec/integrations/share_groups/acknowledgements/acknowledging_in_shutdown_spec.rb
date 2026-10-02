# frozen_string_literal: true

# Share group (KIP-932) acknowledging in `#shutdown`, after the batch was already settled: every
# acknowledgement (async or sync) is a no-op returning false, the shutdown is clean and the
# accepted records are not delivered again to the group.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << message.raw_payload
      @last = message
      mark_as_accepted(message)
    end
  end

  def shutdown
    return unless @last

    DT[:results] << mark_as_rejected(@last)
    DT[:results] << mark_as_released!(@last)
    DT[:results] << mark_as_accepted(@last)
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until(reset_status: true) do
  DT[:deliveries].size >= 5
end

assert_equal [false, false, false], DT[:results]

DT[:results].clear

# A second run in the same group gets only the new record, nothing from the first run is back
# The default producer is closed with the first stop
producer = WaterDrop::Producer.new do |config|
  config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

producer.produce_sync(topic: DT.topic, payload: "next")
producer.close

start_karafka_and_wait_until do
  if DT[:deliveries].include?("next")
    DT[:next_at] = Time.now unless DT.key?(:next_at)

    Time.now - DT[:next_at] > 5
  else
    false
  end
end

assert_equal (elements + ["next"]).sort, DT[:deliveries].sort
