# frozen_string_literal: true

# Share group (KIP-932) topic removed while its records are being processed: whatever errors are
# reported around it, the share group keeps running and consumes the other topic of the group,
# including records produced after the removal, and stops cleanly.
#
# @note After the removal the broker fails the whole share fetch of the session for a while (around
#   30 seconds), so the records of the other topic are delayed until it recovers.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"allow.auto.create.topics"] = false
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:type]
end

class Consumer < Karafka::ShareConsumer
  def consume
    unless DT.key?(:removed)
      Karafka::Admin.delete_topic(DT.topics[0])
      DT[:removed] = true
    end

    messages.each { |message| mark_as_accepted(message) }
  end
end

class OtherConsumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:other] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
    end

    topic DT.topics[1] do
      consumer OtherConsumer
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

produce_many(DT.topics[0], DT.uuids(1))

elements = DT.uuids(10)

start_karafka_and_wait_until do
  if DT.key?(:removed) && !DT.key?(:produced)
    # Give the cluster a moment to notice the removal
    sleep(2)
    produce_many(DT.topics[1], elements)
    DT[:produced] = true
  end

  DT[:other].size >= 10
end

assert_equal elements.sort, DT[:other].sort

topics_names = Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }
assert !topics_names.include?(DT.topics[0])
