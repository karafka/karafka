# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to just process all the jobs one after another and throttling should not
# create any problems aside from throttling
setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
  end
end

draw_routes do
  active_job_topic DT.topic do
    max_messages 20
    throttling(limit: 10, interval: 2_000)
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end
end

50.times { |value| Job.perform_later(value) }

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DT[0].size >= 50
end

assert Time.now.to_f - started_at > 5

# Unordered due to vp
assert_equal DT[0].sort, (0...50).to_a
