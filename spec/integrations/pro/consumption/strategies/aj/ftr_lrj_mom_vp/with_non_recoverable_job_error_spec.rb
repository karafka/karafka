# frozen_string_literal: true

# Karafka should be stuck because we end up in a loop processing and failing

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

setup_active_job

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    raise StandardError if value == 1

    DT[0] << value
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic do
      # mom is enabled automatically
      throttling(limit: 10, interval: 1_000)
      virtual_partitions(
        partitioner: ->(_) { rand(10) }
      )
    end
  end
end

10.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[:errors].size >= 10
end

# No specs, if something goes wrong, may hang
