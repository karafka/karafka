# frozen_string_literal: true

# Karafka should automatically assign the tag of job class that is executed

setup_karafka
setup_active_job

draw_routes do
  active_job_topic DT.topic
end

Karafka.monitor.subscribe("consumer.consumed") do |event|
  DT[:tags] << event[:caller].tags.to_a.first
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[0] << true
  end
end

Job.perform_later

start_karafka_and_wait_until do
  DT.key?(0)
end

assert_equal DT[:tags], [Job.to_s]
