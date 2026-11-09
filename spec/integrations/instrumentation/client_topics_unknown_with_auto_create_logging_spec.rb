# frozen_string_literal: true

# When a subscribed topic does not exist and `allow.auto.create.topics` is on, Karafka should
# publish `client.topics.unknown`, log it at the info level, not report it as an error and keep
# consuming from the existing topic

strio = StringIO.new

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"allow.auto.create.topics"] = true
  config.logger = Logger.new(strio)
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
  end
end

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
produce_many(DT.topics[0], DT.uuids(1))

Karafka.monitor.subscribe("client.topics.unknown") do |event|
  DT[:unknown] << event[:topic]
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error]
end

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  DT.key?(:consumed) && DT[:unknown].any?
end

assert_equal [DT.topics[1]], DT[:unknown].uniq
assert DT[:errors].empty?, DT[:errors]
assert strio.string.include?(
  "Topic #{DT.topics[1]} does not exist yet. Waiting for it to be created."
)
