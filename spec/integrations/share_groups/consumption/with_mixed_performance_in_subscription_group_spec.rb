# frozen_string_literal: true

# Share group (KIP-932) work spread over many subscription groups with consumers of mixed
# performance: the shutdown happens only after all the in-flight work is done, so nothing times
# out and every record that started being processed is accepted.

require "stringio"

strio = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(strio)
  config.concurrency = 10
end

DURATIONS = [3, 0, 1, 0, 2].freeze

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:clients] << client.object_id
    messages.each { |message| DT[:started] << message.raw_payload }
    sleep(DURATIONS[DT.topics.index(topic.name) / 2])

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

TOPICS = DT.topics.first(10)

draw_routes(create_topics: false) do
  share_group DT.group do
    TOPICS.each_slice(2) do |topics|
      subscription_group SecureRandom.hex(6) do
        topics.each do |topic_name|
          topic topic_name do
            consumer Consumer
          end
        end
      end
    end
  end
end

TOPICS.each { |topic_name| setup_share_group(topic_name) }

Karafka.producer.produce_many_sync(
  TOPICS.map { |topic_name| { topic: topic_name, payload: topic_name } }
)

# Stop as soon as all the clients got work, while the slow consumers are still processing
start_karafka_and_wait_until do
  DT[:clients].uniq.size >= 5
end

assert_equal false, strio.string.include?("Timed out"), strio.string
assert DT[:started].size >= 5
assert_equal DT[:started].sort, DT[:accepted].sort
