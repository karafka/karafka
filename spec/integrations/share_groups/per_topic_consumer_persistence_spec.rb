# frozen_string_literal: true

# Share group (KIP-932) topics inherit the global `consumer_persistence` setting but can override
# it per topic: a topic with persistence enabled reuses one consumer instance across batches while
# a topic without it gets a new one for every batch.

setup_karafka do |config|
  config.consumer_persistence = false
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << id
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      consumer_persistence true
    end

    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

assert_equal true, Karafka::App.routes.first.topics[0].consumer_persistence
assert_equal false, Karafka::App.routes.first.topics[1].consumer_persistence

produced = 0

# Produce one record per topic at a time once the previous ones were consumed, so we get several
# batches per topic
start_karafka_and_wait_until do
  if DT[:accepted].size == produced * 2 && produced < 3
    produced += 1
    produce(DT.topics[0], produced.to_s)
    produce(DT.topics[1], produced.to_s)
  end

  DT[:accepted].size >= 6
end

assert_equal 3, DT[DT.topics[0]].size
assert_equal 1, DT[DT.topics[0]].uniq.size
assert_equal 3, DT[DT.topics[1]].size
assert_equal 3, DT[DT.topics[1]].uniq.size
