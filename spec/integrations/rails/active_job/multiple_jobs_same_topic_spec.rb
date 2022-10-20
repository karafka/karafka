# frozen_string_literal: true

# Karafka should be able to handle multiple jobs with same topic

setup_karafka
setup_active_job

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic
  end
end

class Job1 < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[0] << 'job1'
  end
end

class Job2 < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[1] << 'job2'
  end
end

Job1.perform_later
Job2.perform_later

start_karafka_and_wait_until do
  DT[0].size >= 1 &&
    DT[1].size >= 1
end

assert_equal 'job1', DT[0][0]
assert_equal 'job2', DT[1][0]
