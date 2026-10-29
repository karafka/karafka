# frozen_string_literal: true

# Share group (KIP-932) records should be processed in worker threads with the configured worker
# thread priority, and the share group listener should run with the configured listener priority.

setup_karafka do |config|
  config.worker_thread_priority = 2
  config.internal.connection.listener_thread_priority = -2
end

Karafka::App.monitor.subscribe("connection.listener.fetch_loop") do |event|
  next unless event[:subscription_group].group.share_group?

  DT[:listener_thread_priority] = Thread.current.priority
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }

    DT[:worker_thread_priority] = Thread.current.priority
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

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:worker_thread_priority) && DT.key?(:listener_thread_priority)
end

assert_equal 2, DT[:worker_thread_priority]
assert_equal(-2, DT[:listener_thread_priority])
