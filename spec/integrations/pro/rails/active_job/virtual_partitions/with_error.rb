# frozen_string_literal: true

# When we have an vp job and it fails, it should use regular Karafka retry policies for parallel
# jobs

setup_karafka(allow_errors: true) do |config|
  config.license.token = pro_license_token
  config.concurrency = 5
end

setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic do
      virtual_partitioner ->(_) { rand }
    end
  end
end

class Job < ActiveJob::Base
  queue_as DataCollector.topic

  def perform
    if DataCollector[0].size.zero?
      DataCollector[0] << '1'
      raise StandardError
    else
      DataCollector[0] << '2'
    end
  end
end

20.times { Job.perform_later }

start_karafka_and_wait_until do
  DataCollector[0].size >= 2
end

assert_equal '1', DataCollector[0][0]
assert_equal '2', DataCollector[0][1]
