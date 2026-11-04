# frozen_string_literal: true

# Share group (KIP-932) with a separate subscription group for every pair of topics should have
# the proper number of underlying share clients, each consuming records of its own topics only.

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:clients] << [client.object_id, message.topic]
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
  TOPICS.map { |topic_name| { topic: topic_name, payload: "1" } }
)

start_karafka_and_wait_until do
  DT[:clients].size >= 10
end

assert_equal 5, DT[:clients].map(&:first).uniq.size

# Topics of the same subscription group share a client, others do not
clients = DT[:clients].to_h { |client_id, topic_name| [topic_name, client_id] }

TOPICS.each_slice(2) do |first, second|
  assert_equal clients[first], clients[second]
end
