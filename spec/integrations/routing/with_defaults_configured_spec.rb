# frozen_string_literal: true

# Karafka should use the routing defaults if they were configured but only if the appropriate
# per-topic setup was not executed

setup_karafka

draw_routes(create_topics: false) do
  defaults do
    manual_offset_management false
  end

  subscription_group do
    topic "topic1" do
      consumer Class.new
      dead_letter_queue(topic: "xyz", max_retries: 2)
      manual_offset_management true
    end
  end

  topic "topic2" do
    consumer Class.new
  end
end

t1 = Karafka::App.routes.first.topics.first
t2 = Karafka::App.routes.first.topics.last
t3 = Karafka::App.routes.last.topics.last

assert t1.dead_letter_queue?
assert t1.manual_offset_management?

assert !t2.dead_letter_queue?
assert !t2.manual_offset_management?

assert !t3.dead_letter_queue?
assert !t3.manual_offset_management?
