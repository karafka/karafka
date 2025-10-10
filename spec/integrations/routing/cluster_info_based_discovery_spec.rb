# frozen_string_literal: true

# We should be able to build topics based on cluster info

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << message.offset
    end
  end
end

MATCH = SecureRandom.uuid

t1 = "#{DT.topics[0]}-#{MATCH}"
t2 = "#{DT.topics[1]}-#{MATCH}"

Karafka::Admin.create_topic(t1, 1, 1)
Karafka::Admin.create_topic(t2, 1, 1)

draw_routes(create_topics: false) do
  Karafka::Admin
    .cluster_info
    .topics
    .map { |topic| topic[:topic_name] }
    .grep(/#{MATCH}/)
    .each do |name|
      topic name do
        consumer Consumer
      end
    end
end

subscribed_topics = Karafka::App.consumer_groups.first.topics.map(&:name).sort

assert_equal [t1, t2].sort, subscribed_topics, subscribed_topics
