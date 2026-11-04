# frozen_string_literal: true

# Share group (KIP-932) dead letter queue should move failing records from all the partitions of a
# multi-partition source topic into a multi-partition DLQ topic. OSS DLQ does not preserve the
# source partition, so we only check that every record payload made it there.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:partitions] << message.partition
    end

    raise StandardError
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    end
  end
end

setup_share_group(DT.topics[0], DT.group, 10)
Karafka::Admin.create_topic(DT.topics[1], 10, 1)

elements = []

10.times do |i|
  partition_elements = DT.uuids(10)
  elements.concat(partition_elements)
  produce_many(DT.topics[0], partition_elements, partition: i)
end

def dispatched
  Array.new(10) { |i| Karafka::Admin.read_topic(DT.topics[1], i, 100) }.flatten.map(&:raw_payload)
end

start_karafka_and_wait_until(sleep: 1) do
  dispatched.size >= 100
end

assert_equal (0..9).to_a, DT[:partitions].uniq.sort
assert_equal elements.sort, dispatched.sort
