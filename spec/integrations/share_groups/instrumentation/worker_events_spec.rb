# frozen_string_literal: true

# Share group (KIP-932) consume jobs should go through the worker instrumentation:
# worker.process, worker.processed and worker.completed, with the job executor on the share topic.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:batches] << messages.size

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

%w[worker.process worker.processed worker.completed].each do |event_name|
  Karafka::App.monitor.subscribe(event_name) do |event|
    job = event[:job]

    next unless job.is_a?(Karafka::Processing::ShareGroups::Jobs::Consume)

    DT[event_name] << event
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:accepted].size >= 20
end

consume_jobs = DT[:batches].size

%w[worker.process worker.processed worker.completed].each do |event_name|
  events = DT[event_name]

  assert_equal consume_jobs, events.size, event_name

  events.each do |event|
    assert event[:caller].is_a?(Karafka::Processing::Worker)
    assert_equal DT.topic, event[:job].executor.topic.name
    assert event[:job].executor.topic.is_a?(Karafka::Routing::ShareGroups::Topic)
  end
end

assert(DT["worker.processed"].all? { |event| event[:time].is_a?(Numeric) })
assert_equal 20, DT["worker.process"].sum { |event| event[:job].messages.size }
