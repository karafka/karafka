# frozen_string_literal: true

# Parallel consumer should also work with ActiveJob, though it will be a bit undeterministic unless
# we use headers data to balance work.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 5
  config.max_messages = 50
end

setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic do
      # We do not publish any details with this job, thus we do a random work distribution
      virtual_partitioner ->(_) { rand }
    end
  end
end

class Job < ActiveJob::Base
  queue_as DataCollector.topic

  def perform(value)
    DataCollector[0] << value
    DataCollector[:threads_ids] << Thread.current.object_id
  end
end

values = (1..200).to_a
values.each { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 200
end

assert_equal 5, DataCollector[:threads_ids].uniq.count
assert_equal values, DataCollector[0].sort
assert_equal DataCollector[0], DataCollector[0].uniq
