# frozen_string_literal: true

# When we make long polls the same time consumers operate, those operations should be executable
# in parallel.
#
# This spec is to ensure, that no `librdkafka` or `rdkafka-ruby` locks interfere with the expected
# concurrency boundaries of Karafka
#
# It did happen, that due to locking model changes, certain things would heavily impact ability
# to operate concurrently.

setup_karafka do |config|
  config.max_messages = 1
  config.max_wait_time = 15_000
  config.shutdown_timeout = 60_000
end

Karafka.monitor.subscribe('connection.listener.fetch_loop.received') do
  DT[:polls] << Time.now
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Wait so the long poll kicks in
    sleep(5)
    marking
    commiting
    pausing
    revoking

    DT[:times] << Time.now
    DT[:done] = true
  end

  private

  def marking
    DT[:times] << Time.now
    mark_as_consumed(messages.first)
    DT[:times] << Time.now
    mark_as_consumed!(messages.first)
  end

  def commiting
    DT[:times] << Time.now
    commit_offsets
    DT[:times] << Time.now
    commit_offsets!
  end

  def pausing
    DT[:times] << Time.now
    pause(messages.first.offset)
    DT[:times] << Time.now
    resume
  end

  def revoking
    DT[:times] << Time.now
    revoked?
    DT[:times] << Time.now
    retrying?
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert DT[:polls].size >= 2

border_poll = DT[:polls].last

DT[:times].each do |time|
  assert time < border_poll
end
