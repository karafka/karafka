# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we have an vp job and it fails, it should use regular Karafka retry policies for parallel
# jobs

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    virtual_partitions(
      partitioner: ->(_) { rand }
    )
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    if DT[0].empty?
      DT[0] << '1'
      raise StandardError
    else
      DT[0] << '2'
    end
  end
end

20.times { Job.perform_later }

start_karafka_and_wait_until do
  DT[0].size >= 2
end

assert_equal '1', DT[0][0]
assert_equal '2', DT[0][1]
