# frozen_string_literal: true

# When running longer jobs, someone may try to pause processing prior to reaching poll interval
# to bypass the issue. This will not work and this spec illustrates this.

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.max_messages = 1
end

errors = []

Karafka::App.monitor.subscribe("error.occurred") do |event|
  errors << event[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:post)

    DT[:pre] << Time.now.to_f

    # Simulate too long running job
    15.times do |i|
      # We can set it to 1ms because it will be un-paused only after processing
      pause(:consecutive, 1) if i == 8

      sleep(1)
    end

    # This should finish despite exceeding timeouts
    DT[:post] << Time.now.to_f
  end
end

draw_routes(Consumer)

produce(DT.topic, "")

start_karafka_and_wait_until do
  DT.key?(:post)
end

assert_equal :max_poll_exceeded, errors.first.code
assert DT.key?(:post)
assert DT[:post].first - DT[:pre].first >= 15
