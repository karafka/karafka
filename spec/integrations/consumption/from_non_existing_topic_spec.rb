# frozen_string_literal: true

# Karafka in dev should pick up new topic creation fairly fast. It should not wait for 5 minutes

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << 1
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
  end
end

Karafka::Admin.create_topic(DT.topics[1], 1, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
  end

  # We need a second existing topic to which we send nothing, but only then Karafka will not
  # notice immediately the lack of the first topic
  topic DT.topics[1] do
    consumer Consumer2
  end
end

Thread.new do
  sleep 10
  produce(DT.topic, "1")
end

start_karafka_and_wait_until do
  DT.key?(0)
end

topics_names = Karafka::Admin.cluster_info.topics.map { |topics| topics[:topic_name] }
assert topics_names.include?(DT.topic)
