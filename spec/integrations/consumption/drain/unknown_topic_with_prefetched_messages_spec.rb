# frozen_string_literal: true

# When a subscribed topic is deleted while messages of another topic are prefetched and drained,
# the unknown topic error should be reported via `error.occurred`, the client should not be reset
# and all the messages of the other topic should be consumed with no gap.
#
# The deletion happens while the messages produced before it are prefetched and more come after.
# librdkafka hands the error out ahead of the queued messages, so it reaches the blocking poll and
# the drain takes the messages around it.

MESSAGES = 1_000

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.max_messages = 2_000
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error].code if event[:error].respond_to?(:code)
end

Karafka.monitor.subscribe("client.reset") do
  DT[:resets] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:deleting)
      DT[:deleting] = Thread.new do
        # Lets librdkafka queue the rest of the first messages before the error
        sleep(3)
        Karafka::Admin.delete_topic(DT.topics[1])
        sleep(2)
        produce_many(DT.topics[0], DT.uuids(MESSAGES / 2))
      end

      sleep(8)
    end

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

produce_many(DT.topics[0], DT.uuids(MESSAGES / 2))

start_karafka_and_wait_until do
  DT[:offsets].uniq.size >= MESSAGES && DT[:errors].include?(:unknown_topic_or_part)
end

DT[:deleting].join

assert_equal (0...MESSAGES).to_a, DT[:offsets].uniq.sort
assert DT[:errors].include?(:unknown_topic_or_part)
assert DT[:resets].empty?
