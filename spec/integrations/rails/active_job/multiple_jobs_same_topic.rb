# frozen_string_literal: true

# Karafka should be able to handle multiple jobs with same topic

setup_karafka
setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic
  end
end

class Job1 < ActiveJob::Base
  queue_as DataCollector.topic

  def perform
    DataCollector[0] << 'job1'
  end
end

class Job2 < ActiveJob::Base
  queue_as DataCollector.topic

  def perform
    DataCollector[1] << 'job2'
  end
end

Job1.perform_later
Job2.perform_later

start_karafka_and_wait_until do
  DataCollector[0].size >= 1 &&
    DataCollector[1].size >= 1
end

assert_equal 'job1', DataCollector[0][0]
assert_equal 'job2', DataCollector[1][0]
