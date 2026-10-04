# frozen_string_literal: true

# Share group (KIP-932) shutdown jobs should run in the workers threads, not from the share
# listener thread.

setup_karafka do |config|
  # This will ensure all work runs from one worker thread
  config.concurrency = 1
end

Karafka::App.monitor.subscribe("connection.listener.before_fetch_loop") do
  DT[:listener_thread_id] = Thread.current.object_id
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
    DT[:worker_thread_id] = Thread.current.object_id
  end

  def shutdown
    DT[:shutdown_thread_id] = Thread.current.object_id
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

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT.key?(:worker_thread_id)
end

assert DT.key?(:listener_thread_id)
assert DT.key?(:shutdown_thread_id)
assert DT[:listener_thread_id] != DT[:worker_thread_id]
assert_equal DT[:worker_thread_id], DT[:shutdown_thread_id]
