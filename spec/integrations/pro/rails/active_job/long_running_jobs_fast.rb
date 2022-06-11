# frozen_string_literal: true

# Fast jobs should also not have any problems (though not recommended) when running as lrj

setup_karafka do |config|
  config.license.token = pro_license_token
end

setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic do
      long_running_job true
    end
  end
end

class Job < ActiveJob::Base
  queue_as DataCollector.topic

  def perform(value)
    DataCollector.data[0] << value
  end
end

100.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 100
end

100.times do |value|
  assert_equal value, DataCollector.data[0][value]
end
