# frozen_string_literal: true

# Share group (KIP-932): with a sub-second `shutdown_timeout` the in-flight share batch still gets
# a grace window to finish and flush its acknowledgement synchronously. Closing the share consumer
# may not fit in the window, so the process may end gracefully (0) or forcefully (2) - both are
# accepted - but in both cases the in-flight acknowledgement must have been flushed.

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 800
  config.max_wait_time = 100
end

assert Karafka::App.config.shutdown_timeout < 1_000
assert Karafka::App.config.shutdown_timeout > Karafka::App.config.max_wait_time

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:processing] << true

    # Stay in flight until the shutdown was requested. Bounded so a stuck run can never hang.
    500.times do
      break if Karafka::App.stopping?

      sleep(0.01)
    end

    messages.each { |message| mark_as_accepted!(message) }

    DT[:done] << messages.last.offset
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

verify = -> { assert_equal [0], DT[:done] }

Karafka::App.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "app.stopping.error"

  verify.call
end

start_karafka_and_wait_until do
  DT.key?(:processing)
end

verify.call
