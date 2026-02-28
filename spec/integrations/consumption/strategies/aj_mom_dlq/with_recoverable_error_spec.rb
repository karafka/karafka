# frozen_string_literal: true

# When AJ + MoM + DLQ job encounters a recoverable error (fails N times then succeeds),
# no messages should be dispatched to DLQ and all jobs should eventually be processed.

setup_karafka(allow_errors: true)
setup_active_job

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << message.headers["source_offset"].to_i
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topics[0]

  def perform(val)
    DT[:attempts] << val

    if val.zero? && DT[:attempts].count(0) < 3
      raise StandardError
    end

    DT[0] << val
  end
end

draw_routes do
  active_job_topic DT.topics[0] do
    dead_letter_queue topic: DT.topics[1], max_retries: 10
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

5.times { |i| Job.perform_later(i) }

start_karafka_and_wait_until do
  DT[0].uniq.size >= 5
end

# All jobs should have been processed
assert_equal (0..4).to_a, DT[0].uniq.sort
# No messages should have been sent to DLQ since recovery succeeded
assert DT[1].empty?
# Job 0 should have been attempted multiple times
assert DT[:attempts].count(0) >= 3
