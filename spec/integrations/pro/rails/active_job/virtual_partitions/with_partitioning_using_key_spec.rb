# frozen_string_literal: true

# We should be able to mix partition delegation via `:key` with virtual partitions to achieve
# concurrent Active Job work execution.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

setup_active_job

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic do
      virtual_partitions(
        partitioner: ->(job) { job.key }
      )
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first[0] },
    partition_key_type: :key
  )

  def perform(value1)
    DT[0] << value1
  end
end

order_without_vp = []

100.times do
  2.times do |iteration|
    order_without_vp << iteration.to_s
    Job.perform_later(iteration.to_s)
  end
end

start_karafka_and_wait_until do
  DT[0].size >= 200
end

assert_equal DT[0].size, order_without_vp.size

# Without virtual partitions we should get a consistent order, but with them and concurrent
# processing, it should not be like that
assert DT[0] != order_without_vp
