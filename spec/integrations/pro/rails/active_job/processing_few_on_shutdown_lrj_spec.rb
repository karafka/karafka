# frozen_string_literal: true

# Karafka with PRO should finish processing AJ jobs as fast as possible even if more were received
# in the batch. Since we are shutting down, those jobs will be picked up after Karafka is started
# again, so not worth waiting.
# The above should apply also to LRJ.

setup_karafka do |config|
  # This will ensure we get more jobs in one go
  config.max_wait_time = 5_000
end

setup_active_job

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic do
      long_running_job true
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync
  )

  def perform(value)
    # We add sleep to simulate work being done, so it ain't done too fast before we shutdown
    if DT[:stopping].size.zero?
      DT[:stopping] << true
      sleep(5)
    end

    DT[0] << value
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  !DT[:stopping].size.zero?
end

assert_equal 1, DT[0].size
