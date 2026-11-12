# frozen_string_literal: true

# The share group (KIP-932) dead letter queue is a Pro feature. Without Pro, setting it on a share
# group topic should fail when the routes are drawn, same as other Pro-only routing features.

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Class.new(Karafka::ShareConsumer)
        dead_letter_queue(topic: "dlq", max_retries: 2)
      end
    end
  end
rescue NoMethodError => e
  assert_equal :dead_letter_queue, e.name

  failed = true
end

assert failed
