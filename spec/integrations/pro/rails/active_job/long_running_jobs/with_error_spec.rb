# frozen_string_literal: true

# When we have an lrj job and it fails, it should use regular Karafka retry policies

setup_karafka(allow_errors: true)

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

  def perform
    sleep 5

    if DT[0].empty?
      DT[0] << '1'
      raise StandardError
    else
      DT[0] << '2'
    end
  end
end

Job.perform_later

start_karafka_and_wait_until do
  DT[0].size >= 2
end

assert_equal '1', DT[0][0]
assert_equal '2', DT[0][1]
