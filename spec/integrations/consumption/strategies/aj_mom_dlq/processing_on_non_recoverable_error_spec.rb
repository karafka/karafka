# frozen_string_literal: true

# When there is ActiveJob processing error that cannot recover, upon moving to DLQ, the offset
# should be moved as well and we should continue.

setup_karafka(allow_errors: true)
setup_active_job

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topics[0] do
      dead_letter_queue topic: DT.topics[1], max_retries: 1
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topics[0]

  def perform(val)
    DT[0] << val

    raise(StandardError) if val.zero?
  end
end

5.times { |i| Job.perform_later(i) }

start_karafka_and_wait_until do
  DT[0].uniq.size >= 3
end

assert DT[0].count(0) == 2, DT[0]
