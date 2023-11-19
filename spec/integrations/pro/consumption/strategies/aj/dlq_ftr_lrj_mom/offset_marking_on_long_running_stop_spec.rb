# frozen_string_literal: true

# Karafka upon long running jobs shutdown in this scenario, should early stop but should not
# mark the non-processed messages as consumed.

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 100
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value

    # First message is often the only in the first batch thuse we skip it
    sleep(15) if value > 0
  end
end

draw_routes do
  active_job_topic DT.topic do
    long_running_job true
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    throttling(limit: 3, interval: 2_000)
  end
end

3.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 2
end

# No test needed, if it commits last offset, this will hang forever
fetch_first_offset
