# frozen_string_literal: true

# Share group (KIP-932) records acquired by a member that leaves the group without acknowledging
# them are released on its close and delivered to Karafka (as a second delivery), long before
# their acquisition lock would expire.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]
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

SUBSCRIPTION_GROUP = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

elements = DT.uuids(10)
produce_many(DT.topic, elements)

member = Rdkafka::Config.new(SUBSCRIPTION_GROUP.kafka).share_consumer
member.subscribe(DT.topic)

acquired = []
acquired = member.poll(500).map(&:payload) while acquired.empty?

# Leave without acknowledging anything
member.close

started_at = Time.now

start_karafka_and_wait_until do
  DT[:deliveries].map(&:first).uniq.size >= 10
end

delivered = DT[:deliveries].to_h

assert_equal elements.sort, delivered.keys.sort
assert_equal DT[:deliveries].size, delivered.size
# Released on close, not after the default 30 seconds lock
assert Time.now - started_at < 25

elements.each do |element|
  assert_equal acquired.include?(element) ? 2 : 1, delivered.fetch(element)
end
