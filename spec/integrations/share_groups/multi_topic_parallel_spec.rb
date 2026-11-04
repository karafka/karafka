# frozen_string_literal: true

# Share group (KIP-932) consuming many independent topics uses more than one worker thread to
# process them.

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::ShareConsumer
  def consume
    # This will simulate, that the thread is busy, so more worker threads can be occupied
    sleep(0.1)

    messages.each do |message|
      DT[:threads] << Thread.current.object_id
      DT[topic.name] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    DT.topics.first(10).each do |topic_name|
      topic topic_name do
        consumer Consumer
      end
    end
  end
end

elements = {}

DT.topics.first(10).each do |topic_name|
  setup_share_group(topic_name)
  elements[topic_name] = DT.uuids(10)
end

elements.each { |topic_name, payloads| produce_many(topic_name, payloads) }

start_karafka_and_wait_until do
  elements.keys.all? { |topic_name| DT[topic_name].size >= 10 }
end

elements.each do |topic_name, payloads|
  assert_equal payloads.sort, DT[topic_name].sort
end

# More than one worker was in use
assert DT[:threads].uniq.size > 1
