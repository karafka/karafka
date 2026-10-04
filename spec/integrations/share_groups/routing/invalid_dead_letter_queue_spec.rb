# frozen_string_literal: true

# The share group (KIP-932) dead letter queue routing settings should be validated: negative
# max_retries, unknown dispatch methods and invalid target topic names are rejected, while
# `topic: false` (reject without dispatch) and a regular target topic are accepted.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

def draw_dlq(**options)
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Consumer
        dead_letter_queue(**options)
      end
    end
  end
end

invalid = {
  "routes.sg.t.dead_letter_queue.max_retries" => { topic: "dlq", max_retries: -1 },
  "routes.sg.t.dead_letter_queue.dispatch_method" => { topic: "dlq", dispatch_method: :produce },
  "routes.sg.t.dead_letter_queue.topic" => { topic: '#$%^&*(' }
}

invalid.each do |key, options|
  failed = false

  begin
    draw_dlq(**options)
  rescue Karafka::Errors::InvalidConfigurationError => e
    assert e.message.include?(key), e.message

    failed = true
  end

  assert failed, options

  clear_app_draws
end

# Rejecting without dispatching anywhere is valid
draw_dlq(topic: false, max_retries: 0)

topic = Karafka::App.routes.share_groups.first.topics.first

assert topic.dead_letter_queue?
assert_equal false, topic.dead_letter_queue.topic
assert_equal 0, topic.dead_letter_queue.max_retries

clear_app_draws

# A regular target topic with a sync dispatch is valid
draw_dlq(topic: "dlq-target", max_retries: 2, dispatch_method: :produce_sync)

topic = Karafka::App.routes.share_groups.first.topics.first

assert topic.dead_letter_queue?
assert_equal "dlq-target", topic.dead_letter_queue.topic
assert_equal :produce_sync, topic.dead_letter_queue.dispatch_method

clear_app_draws

# Without a topic the dead letter queue is not active
draw_dlq(max_retries: 2)

assert !Karafka::App.routes.share_groups.first.topics.first.dead_letter_queue?
