# frozen_string_literal: true

# Karafka should finish processing all the jobs that it has from current messages batch before
# completely shutting down
#
# @note This behaviour is different with PRO AJ consumer, where Karafka waits only on the currently
#   processed work (for LRJ and without LRJ)

setup_karafka do |config|
  # This will ensure we get more jobs in one go
  config.max_wait_time = 5_000
end

setup_active_job

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync
  )

  def perform(value)
    # We add sleep to simulate work being done, so it ain't done too fast before we shutdown
    DT[:stopping] << true
    sleep(5)

    DT[0] << value
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[:stopping].size >= 2
end

assert DT[0].size > 1
