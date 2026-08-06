# frozen_string_literal: true

# When running the fibers workers backend, errors raised in fiber jobs should go through the
# regular retry flow with pausing and the work should eventually complete

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    if DT[:raised].empty?
      DT[:raised] << true

      raise StandardError
    end

    DT[:attempts] << coordinator.pause_tracker.attempt

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:offsets].uniq.size >= 10
end

# The error triggered a retry (attempt > 1) and all data was consumed after it
assert DT[:attempts].any? { |attempt| attempt > 1 }, DT[:attempts]
assert_equal (0..9).to_a, DT[:offsets].uniq.sort
