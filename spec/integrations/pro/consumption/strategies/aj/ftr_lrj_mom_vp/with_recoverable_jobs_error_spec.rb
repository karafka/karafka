# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should recover from this error and move forward slowing things down throttling

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

setup_active_job

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true)

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value

    raise StandardError if DT[0].size < 5
  end
end

draw_routes do
  active_job_topic DT.topic do
    throttling(limit: 10, interval: 1_000)
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end
end

20.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[:errors].size >= 4
end

assert DT[:errors].count >= 4
