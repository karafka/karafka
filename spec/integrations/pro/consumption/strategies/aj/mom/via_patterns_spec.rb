# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should allow to define ActiveJob patterns via `#active_job_pattern` and those should
# be picked up and operable even when topics are created after the subscription starts

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

setup_active_job

draw_routes(create_topics: false) do
  active_job_pattern(/(#{DT.topics[0]}|#{DT.topics[1]})/)
end

class Job1 < ActiveJob::Base
  queue_as DT.topics[0]

  def perform
    DT[0] << true
  end
end

class Job2 < ActiveJob::Base
  queue_as DT.topics[1]

  def perform
    DT[1] << true
  end
end

start_karafka_and_wait_until do
  sleep(2)

  unless @sent
    Job1.perform_later
    Job2.perform_later
    @sent = true
  end

  DT.key?(0) && DT.key?(1)
end
