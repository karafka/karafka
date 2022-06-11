# frozen_string_literal: true

# When we have a batch of ActiveJobs jobs and we loose our partition assignment, jobs that
# did not start prior to the revocation should not start at all.

# To simulate this we will run long jobs from two partitions in parallel and we will "loose" one
# of them and detect this.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.max_wait_time = 2_500
  config.concurrency = 10
  config.shutdown_timeout = 60_000
end

setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic 'integrations_3_02' do
      long_running_job true
    end
  end
end

class Job < ActiveJob::Base
  queue_as 'integrations_3_02'

  karafka_options(
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first[0] }
  )

  # This job is so slow, that while it is running another consumer joins in and should take over
  # one partition.
  # If this would not happen, we should not stop until all batches of jobs are processed
  def perform(value1)
    DataCollector[:started] << value1
    sleep(20)
    DataCollector[:done] << value1
  end
end

consumer = setup_rdkafka_consumer

# 3 really slow jobs per partition
# 1 and 4 are picked because they will dispatch messages to 0 and 1 partition
3.times do
  Job.perform_later('1')
  Job.perform_later('4')
end

revoked = false

# This will trigger a rebalance when the first job is being processed
Thread.new do
  sleep(10)

  consumer.subscribe('integrations_3_02')

  consumer.each do
    unless revoked
      sleep(5)
      revoked = true
    end

    break
  end

  consumer.close
end

start_karafka_and_wait_until do
  DataCollector[:started].size >= 2 && revoked
end

# We should finish only one job per each partition as the rest should be stopped from being
# processed upon revocation
assert_equal 2, DataCollector[:started].size
assert_equal 2, DataCollector[:done].size
