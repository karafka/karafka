# frozen_string_literal: true

# Share group (KIP-932) can subscribe to and consume from many topics at once within a single
# share group.

setup_karafka do |config|
  config.concurrency = 5
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:topics] << message.topic
      mark_as_accepted(message)
    end
  end
end

TOPICS = DT.topics.first(25)

draw_routes(create_topics: false) do
  share_group DT.group do
    TOPICS.each do |topic_name|
      topic topic_name do
        consumer Consumer
      end
    end
  end
end

TOPICS.each { |topic_name| setup_share_group(topic_name) }

messages = TOPICS.map do |topic_name|
  { topic: topic_name, payload: "1" }
end

Karafka.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:topics].uniq.size >= TOPICS.size
end

assert_equal TOPICS.sort, DT[:topics].uniq.sort
