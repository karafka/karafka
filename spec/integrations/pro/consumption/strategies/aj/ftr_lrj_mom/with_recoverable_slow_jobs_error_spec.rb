# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should recover from this error and move on. Throttling should not impact order or
# anything else.

setup_active_job

setup_karafka(allow_errors: true)

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
    sleep(value.to_f / 100)
    raise StandardError if DT[0].size < 5
  end
end

draw_routes do
  active_job_topic DT.topic do
    max_messages 20
    long_running_job true
    # mom is enabled automatically
    throttling(limit: 10, interval: 2_000)
  end
end

50.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].uniq.size >= 50
end

assert_equal DT[0], [0, 0, 0, 0, 0] + (1..49).to_a
