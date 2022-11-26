# frozen_string_literal: true

# Fast jobs should also not have any problems (though not recommended) when running as lrj

setup_karafka

setup_active_job

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic do
      long_running_job true
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
  end
end

100.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 100
end

100.times do |value|
  assert_equal value, DT[0][value]
end
