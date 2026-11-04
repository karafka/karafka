# frozen_string_literal: true

# Routing defaults should apply to share group (KIP-932) topics the same way as to consumer group
# topics: share-applicable settings from the defaults block are used unless the topic configured
# them itself.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

draw_routes(create_topics: false) do
  defaults do
    consumer Consumer
    acknowledgements(unacknowledged: :accept)
    dead_letter_queue(topic: "default-dlq", max_retries: 1)
  end

  share_group "sg" do
    topic "t1" do
      acknowledgements(unacknowledged: :reject)
      dead_letter_queue(topic: "custom-dlq", max_retries: 2)
    end

    topic "t2"
  end

  share_group "sg2" do
    topic "t3"
  end
end

t1, t2 = Karafka::App.routes.share_groups.first.topics.to_a
t3 = Karafka::App.routes.share_groups.last.topics.first

assert_equal Consumer, t1.consumer
assert_equal :reject, t1.acknowledgements.unacknowledged
assert_equal "custom-dlq", t1.dead_letter_queue.topic
assert_equal 2, t1.dead_letter_queue.max_retries

[t2, t3].each do |topic|
  assert_equal Consumer, topic.consumer
  assert_equal :accept, topic.acknowledgements.unacknowledged
  assert_equal "default-dlq", topic.dead_letter_queue.topic
  assert_equal 1, topic.dead_letter_queue.max_retries
end
