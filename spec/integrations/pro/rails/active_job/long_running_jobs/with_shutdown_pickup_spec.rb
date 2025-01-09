# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka with lrj ActiveJob when finishing in the middle of jobs on shutdown, should pick up
# where it stopped when started again
#
# We test it by starting a new consumer just to get the first message offset

setup_karafka do |config|
  # This will ensure we get more jobs in one go
  config.max_wait_time = 5_000
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    long_running_job true
    manual_offset_management true
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync
  )

  def perform(value)
    # We add sleep to simulate work being done, so it ain't done too fast before we shutdown
    if DT[:stopping].empty?
      DT[:stopping] << true
      sleep(5)
    end

    DT[0] << value
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  !DT[:stopping].empty?
end

# Give Karafka time to finalize everything
sleep(2)

assert_equal DT[0][0] + 1, fetch_next_offset
