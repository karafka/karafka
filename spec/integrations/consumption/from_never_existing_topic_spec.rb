# frozen_string_literal: true

# Karafka should work when subscribing to a topic that does not exist
# This should operate even if topic is not created as it may be in the future.
# Even if not created, we should still be able to operate, start and stop

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  sleep(5)
  true
end

topics_names = Karafka::Admin.cluster_info.topics.map { |topics| topics[:topic_name] }
assert !topics_names.include?(DT.topic)
