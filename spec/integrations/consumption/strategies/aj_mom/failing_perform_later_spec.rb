# frozen_string_literal: true

# OSS Karafka should not support `#enqueue_at`

setup_karafka(allow_errors: true)
setup_active_job

draw_routes do
  active_job_topic DT.topic
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform; end
end

failed = false

begin
  Job.set(wait: 1.week).perform_later
rescue NotImplementedError
  failed = true
end

assert failed
