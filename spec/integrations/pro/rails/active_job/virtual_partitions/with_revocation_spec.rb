# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we have a batch of ActiveJobs jobs and we loose our partition assignment, jobs that
# did not start prior to the revocation should not start at all.

# To simulate this we will have jobs on two partitions in parallel and we will "loose" one
# of them and detect this. We need to make consumption jobs long enough to jump with a rebalance
# in the middle. Since we internally mark as consumed on each job, we can be aware of revocation
# early enough. We need to run in an LRJ mode to make this happen, so rebalance does not block
# revocation.

# Note that for LRJ + VP, under shutdown we need to finish processing all because otherwise we
# might end up having extensive reprocessing

setup_karafka do |config|
  config.max_wait_time = 1_000
  config.max_messages = 20
  config.concurrency = 4
  config.shutdown_timeout = 100_000
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    long_running_job true
    config(partitions: 2)
    virtual_partitions(
      partitioner: ->(_) { rand }
    )
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first[0] }
  )

  # This job is so slow, that while it is running another consumer joins in and should take over
  # one partition.
  # If this would not happen, we should not stop until all batches of jobs are processed
  def perform(value1, _value2)
    DT[:started] << value1
    sleep(20)
    DT[:done] << value1
  end
end

consumer = setup_rdkafka_consumer

# 1 and 4 are picked because they will dispatch messages to 0 and 1 partition
10.times do |i|
  Job.perform_later('1', i)
  Job.perform_later('4', i)
end

revoked = false
stopped = false

# This will trigger a rebalance when the first job is being processed
# We keep it alive so we do not trigger a second rebalance
other = Thread.new do
  sleep(0.1) until DT[:started].size >= 4

  consumer.subscribe(DT.topic)

  consumer.each do
    break if revoked

    sleep(5)
    revoked = true

    sleep(0.1) until stopped

    break
  end
end

start_karafka_and_wait_until do
  DT[:started].size >= 4 && revoked && sleep(5)
end

stopped = true

assert DT[:started].size < 10
assert DT[:done].size < 10

other.join
consumer.close
