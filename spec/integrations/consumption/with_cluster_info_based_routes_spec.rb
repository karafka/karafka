# frozen_string_literal: true

# We should be able to define settings and then use cluster info to get topics and subscribe
# to them automatically also matching via regexp

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
    .select { |name| name =~ /#{MATCH}/ }
    .each do |name|
      topic name do
        consumer Consumer
      end
    end
end

elements = DT.uuids(10)
produce_many(t1, elements)
produce_many(t2, elements)

start_karafka_and_wait_until do
  DT[t1].size >= 10 && DT[t2].size >= 10
end

assert_equal DT[t1], (0..9).to_a
assert_equal DT[t2], (0..9).to_a
