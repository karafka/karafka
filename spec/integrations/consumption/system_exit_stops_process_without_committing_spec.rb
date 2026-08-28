# frozen_string_literal: true

# When user code raises a process-critical error (here SystemExit via `exit`), Karafka should
# honor its meaning: record the failure, keep the failed batch unmarked (the retry pause
# protects the partition during the shutdown window, so no later batch can be processed and
# auto-marked past it) and initiate a graceful shutdown instead of retrying in-process.
# After a restart, the failed batch is redelivered - at-least-once is preserved through the
# process death.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # In the first run, offset 2 always exits - simulating a consumer that deterministically
      # terminates the process on a given message. In the second run (after restart) it is
      # processed normally
      exit(1) if message.offset == 2 && !DT.key?(:second_run)

      DT[:consumed] << message.offset
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

# First run: offsets 0 and 1 are consumed and marked, then offset 2 triggers the self-initiated
# graceful shutdown. The wait block only observes - the stop is initiated by the framework
start_karafka_and_wait_until(reset_status: true) do
  DT[:consumed].size >= 2 && Karafka::App.done?
end

# Only the messages before the critical one were consumed - the pause prevented offsets 3 and 4
# from being processed and marked during the shutdown window
assert_equal [0, 1], DT[:consumed].uniq.sort

# The committed offset must point at the failed batch, not past it
assert_equal 2, fetch_next_offset

DT[:second_run] = true

# Second run: the failed batch is redelivered and everything processes to the end
start_karafka_and_wait_until do
  ((0..4).to_a - DT[:consumed].uniq).empty?
end

assert_equal (0..4).to_a, DT[:consumed].uniq.sort
