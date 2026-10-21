# frozen_string_literal: true

# Share group (KIP-932) listener emits `connection.listener.fetch_loop.received` after each poll,
# like for consumer groups, with a messages buffer grouping the polled records per topic partition.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
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

setup_share_group(DT.topic, DT.group, 2)

Karafka.monitor.subscribe("connection.listener.fetch_loop.received") do |event|
  buffer = event[:messages_buffer]

  DT[:listeners] << event[:caller].class
  DT[:polled] << buffer.size

  buffer.each do |topic, partition, messages, eof|
    DT[:groups] << [topic, partition, messages.map(&:partition).uniq, eof]
  end
end

elements = DT.uuids(10)
elements.each_with_index { |payload, index| produce(DT.topic, payload, partition: index % 2) }

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 10
end

assert_equal [Karafka::Connection::ShareGroups::Listener], DT[:listeners].uniq
assert DT[:polled].sum >= 10

DT[:groups].each do |topic, partition, partitions, eof|
  assert_equal DT.topic, topic
  assert_equal [partition], partitions
  assert_equal false, eof
end
