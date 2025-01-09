# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we have an vp and not the first job fails, it should use regular Karafka retry policies
# for parallel jobs. It should mark previously done work as consumed accordingly to the VPs
# virtual offset management.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
  config.max_messages = 60
  config.max_wait_time = 2_000
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    virtual_partitions(
      partitioner: ->(_) { [true, false].sample }
    )
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(number)
    if number == 95 && !DT[0].include?(number)
      DT[0] << number
      raise StandardError
    end

    DT[0] << number

    sleep 0.1
  end
end

100.times { |i| Job.perform_later(i) }

start_karafka_and_wait_until do
  DT[0].uniq.sort.size >= 100
end

assert_equal 1, (DT[0].count { |nr| nr == 94 })
assert_equal 2, (DT[0].count { |nr| nr == 95 })
assert_equal DT[0].uniq.sort, (0..99).to_a
