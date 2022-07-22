# frozen_string_literal: true

# Karafka should be able to finish a big batch of jobs early when we decide to stop
# All the jobs from the batch should not be processed and we should early exit.

setup_karafka do |config|
  config.max_wait_time = 5_000
  config.max_messages = 1_000
end

setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic
  end
end

class Job < ActiveJob::Base
  queue_as DataCollector.topic

  def perform
    DataCollector[0] << true

    # Simulate some delay, otherwise jobs will be faster than shutdown
    sleep(0.5)
  end
end

100.times { Job.perform_later }

start_karafka_and_wait_until do
  DataCollector[0].size >= 3
end

# We should not process all the messages but just few
assert DataCollector[0].size <= 5
