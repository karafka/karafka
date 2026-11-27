# frozen_string_literal: true

# Karafka should publish each successful offset commit as `client.offsets.committed`, from the
# client that committed it. Each subscription group has its own client, so its event must carry
# only its own client id and offsets.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:client_ids][topic.name] = client.id

    mark_as_consumed!(messages.last)
  end
end

draw_routes do
  subscription_group "a" do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  subscription_group "b" do
    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

DT[:client_ids] = {}
committed = Queue.new

Karafka::App.monitor.subscribe("client.offsets.committed") do |event|
  committed << event
end

produce(DT.topics[0], "1")
produce(DT.topics[1], "1")

events = []

start_karafka_and_wait_until do
  events << committed.pop until committed.empty?

  DT.topics.first(2).all? do |topic_name|
    events.any? { |event| event[:tpl].to_h.key?(topic_name) }
  end
end

DT.topics.first(2).each do |topic_name|
  event = events.find { |e| e[:tpl].to_h.key?(topic_name) }

  assert_equal DT[:client_ids][topic_name], event[:client_id]
  assert_equal [topic_name], event[:tpl].to_h.keys
  assert_equal [1], event[:tpl].to_h[topic_name].map(&:offset)
  assert_equal event[:subscription_group].id, event[:subscription_group_id]
end

assert_not_equal DT[:client_ids][DT.topics[0]], DT[:client_ids][DT.topics[1]]
