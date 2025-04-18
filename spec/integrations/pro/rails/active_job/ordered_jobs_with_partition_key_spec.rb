# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using the pro adapter, we should be able to use partitioner that will allow us to process
# ActiveJob jobs in their scheduled order using multiple partitions. We should be able to get
# proper results when using `:partition_key`.

setup_karafka do |config|
  config.initial_offset = 'latest'
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    config(partitions: 3)
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first[0] },
    partition_key_type: :partition_key
  )

  def perform(value1)
    DT[0] << value1
  end
end

counts = 0

# First loop kicks in before initialization of the connection and we want to publish after, that
# is why we don't run it on the first run
Karafka::App.monitor.subscribe('connection.listener.fetch_loop') do
  counts += 1

  if counts == 20
    # We dispatch in order per partition, in case it all would go to one without partitioner or
    # in case it would fail, the order will break
    2.downto(0) do |partition|
      3.times do |iteration|
        Job.perform_later("#{partition}#{iteration}")
      end
    end
  end
end

start_karafka_and_wait_until do
  DT[0].size >= 9
end

groups = DT[0].group_by { |element| element[0] }
groups.transform_values! { |group| group.map(&:to_i) }

groups.each_value do |values|
  assert_equal values.sort, values
end
