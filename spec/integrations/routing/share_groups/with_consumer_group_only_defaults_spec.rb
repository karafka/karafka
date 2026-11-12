# frozen_string_literal: true

# The routing `defaults` block applies to consumer-group topics only. Consumer-group-only calls in
# it (`config`, `dead_letter_queue`) must not raise when a share group is drawn, and share topics
# must not receive any of the defaults.

setup_karafka

draw_routes(create_topics: false) do
  defaults do
    config(partitions: 2)
    dead_letter_queue(topic: "dlq", max_retries: 1, independent: true)
    max_messages 7
  end

  consumer_group "cg" do
    topic "regular" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg" do
    topic "share-topic" do
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

cg_topic = Karafka::App.routes.consumer_groups.first.topics.first
sg_topic = Karafka::App.routes.share_groups.first.topics.first

assert_equal 2, cg_topic.declaratives.partitions
assert cg_topic.dead_letter_queue?
assert_equal "dlq", cg_topic.dead_letter_queue.topic
assert_equal true, cg_topic.dead_letter_queue.independent
assert_equal 7, cg_topic.max_messages

assert !sg_topic.respond_to?(:dead_letter_queue)
assert !sg_topic.respond_to?(:declaratives)
assert !sg_topic.to_h.key?(:dead_letter_queue)
assert_equal Karafka::App.config.max_messages, sg_topic.max_messages
