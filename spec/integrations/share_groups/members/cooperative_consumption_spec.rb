# frozen_string_literal: true

# Share group (KIP-932) members consume cooperatively: Karafka and a second member of the same
# share group split the records of a multi-partition topic, both get some and every record is
# accepted exactly once across them.

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:karafka] << message.raw_payload
      mark_as_accepted(message)
    end

    # Slow down a bit, so the other member gets its share of the work
    sleep(0.2)
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topic, DT.group, 4)

SUBSCRIPTION_GROUP = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

elements = DT.uuids(200)

member = Thread.new do
  consumer = Rdkafka::Config.new(SUBSCRIPTION_GROUP.kafka).share_consumer
  consumer.subscribe(DT.topic)

  until DT.key?(:stop)
    records = consumer.poll(100)

    records.each do |record|
      DT[:member] << record.payload
      consumer.acknowledge(record, :accept)
    end

    consumer.commit_sync unless records.empty?

    # Slow down the same way as Karafka
    sleep(0.2) unless records.empty?
  end

  consumer.close
end

Thread.new do
  sleep(5)
  elements.each_slice(10) do |slice|
    produce_many(DT.topic, slice)
    sleep(0.1)
  end
end

start_karafka_and_wait_until do
  (DT[:karafka].size + DT[:member].size) >= 200
end

DT[:stop] = true
member.join

all = DT[:karafka] + DT[:member]

assert_equal elements.sort, all.sort
assert_equal all.size, all.uniq.size
assert !DT[:karafka].empty?
assert !DT[:member].empty?
