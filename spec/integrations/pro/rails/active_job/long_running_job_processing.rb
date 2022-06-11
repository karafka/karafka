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
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic do
      long_running_job true
    end
  end
end

class Job < ActiveJob::Base
  queue_as DataCollector.topic

  def perform
    # Ensure we exceed max poll interval, if that happens and this would not work async we would
    # be kicked out of the group
    sleep(15)
    DataCollector.data[0] << true
  end
end

# We need a second producer so we are sure that there was no revocation due to a timeout
config = {
  'bootstrap.servers': 'localhost:9092',
  'group.id': Karafka::App.consumer_groups.first.id,
  'auto.offset.reset': 'earliest'
}
consumer = Rdkafka::Config.new(config).consumer

Thread.new do
  sleep(10)

  consumer.subscribe(DataCollector.topic)

  consumer.each do
    # This should never happen.
    # We have one partition and it should be karafka that consumes it
    exit! 5
  end
end

Job.perform_later

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 1
end

assert_equal 1, DataCollector.data[0].size, 'Given job should be executed only once'

consumer.close
