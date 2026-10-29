# frozen_string_literal: true

# Share group (KIP-932) restart in the same process: records produced while Karafka was stopped
# are consumed after it starts again, while records accepted before the stop are not redelivered.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[DT[:phase].last] << [message.raw_payload, message.delivery_count]
      mark_as_accepted(message)
    end
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

old_elements = DT.uuids(10)
produce_many(DT.topic, old_elements)

DT[:phase] << 1

start_karafka_and_wait_until(reset_status: true) do
  DT[1].size >= 10
end

# The default producer is closed with the first stop
producer = WaterDrop::Producer.new do |config|
  config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

new_elements = DT.uuids(10)
producer.produce_many_sync(new_elements.map { |payload| { topic: DT.topic, payload: payload } })
producer.close

DT[:phase] << 2

# Run longer than needed, so a redelivery of the old records would show up
start_karafka_and_wait_until do
  DT[2].size >= 10 && sleep(5)
end

assert_equal old_elements.sort, DT[1].map(&:first).sort
assert_equal new_elements.sort, DT[2].map(&:first).sort
assert_equal [1], (DT[1] + DT[2]).map(&:last).uniq
