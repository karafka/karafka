# frozen_string_literal: true

# A process-critical error (SystemExit via `exit`) raised from an ActiveJob job with a DLQ
# must NOT dispatch the job to the DLQ even when retries are exhausted (max_retries: 0
# dispatches on the first attempt for regular errors). Only the jobs that completed are
# marked, so after the restart the failed job is redelivered and executed.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

setup_active_job

draw_routes do
  active_job_topic DT.topics[0] do
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end
end

class Job < ActiveJob::Base
  queue_as DT.topics[0]

  def perform(val)
    exit(1) if val == 2 && !DT.key?(:second_run)

    DT[:performed] << val
  end
end

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |_event|
  DT[:dispatched] << 1
end

5.times { |i| Job.perform_later(i) }

start_karafka_and_wait_until(reset_status: true) do
  DT[:performed].size >= 2 && Karafka::App.done?
end

assert_equal [], DT[:dispatched]
assert_equal [0, 1], DT[:performed].uniq.sort
assert_equal 2, fetch_next_offset(DT.topics[0])

DT[:second_run] = true

start_karafka_and_wait_until do
  ((0..4).to_a - DT[:performed].uniq).empty?
end

assert_equal (0..4).to_a, DT[:performed].uniq.sort
assert_equal [], DT[:dispatched]
