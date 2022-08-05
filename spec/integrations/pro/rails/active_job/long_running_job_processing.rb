# frozen_string_literal: true

# When a job is marked as lrj, it should keep running longer than max poll interval and all
# should be good

setup_karafka do |config|
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.license.token = pro_license_token
end

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

  def perform
    # Ensure we exceed max poll interval, if that happens and this would not work async we would
    # be kicked out of the group
    sleep(15)
    DT[0] << true
  end
end

Job.perform_later

start_karafka_and_wait_until do
  if DT[0].size >= 1
    sleep(15)
    true
  end
end

assert_equal 1, DT[0].size, 'Given job should be executed only once'
