# frozen_string_literal: true

# Karafka when running VPs with AJ and being saturated, should run further jobs if the first
# job in the queue failed because we use virtual offset management for handling this scenario.

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 100
  # Force saturation by not having enough threads
  config.concurrency = 1
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value

    return if value == 0

    raise StandardError
  end
end

draw_routes do
  active_job_topic DT.topic do
    virtual_partitions(
      partitioner: ->(message) { message.offset % 10 },
      max_partitions: 10
    )
  end
end

100.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert(DT[0].uniq.count >= 10)
