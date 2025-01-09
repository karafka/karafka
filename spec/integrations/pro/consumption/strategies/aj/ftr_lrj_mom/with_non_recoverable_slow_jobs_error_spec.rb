# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should end up in a loop and not move forward. Throttling should not interrupt this

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
    sleep(value.to_f / 20)
    raise StandardError
  end
end

draw_routes do
  active_job_topic DT.topic do
    long_running_job true
    # mom is enabled automatically
    throttling(limit: 10, interval: 2_000)
  end
end

50.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 5
end

assert_equal [0], DT[0].uniq
