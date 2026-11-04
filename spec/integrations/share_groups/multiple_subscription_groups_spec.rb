# frozen_string_literal: true

# Share group (KIP-932) with separate subscription groups: each subscription group has its own
# underlying share client and fetches its data independently.

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:clients] << client.object_id
      DT[message.topic] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

TOPICS = DT.topics.first(5)

draw_routes(create_topics: false) do
  share_group DT.group do
    TOPICS.each do |topic_name|
      subscription_group topic_name do
        topic topic_name do
          consumer Consumer
        end
      end
    end
  end
end

TOPICS.each { |topic_name| setup_share_group(topic_name) }

assert_equal 5, Karafka::App.routes.first.subscription_groups.size

messages = TOPICS.map do |topic_name|
  { topic: topic_name, payload: topic_name }
end

Karafka.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:clients].uniq.size >= 5 && TOPICS.all? { |topic_name| DT.key?(topic_name) }
end

assert_equal 5, DT[:clients].uniq.size

TOPICS.each do |topic_name|
  assert_equal [topic_name], DT[topic_name]
end
