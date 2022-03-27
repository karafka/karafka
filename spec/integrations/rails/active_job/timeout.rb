# frozen_string_literal: true

# Karafka should never process the same job multiple times from one perform call

setup_karafka do |config|
  config.concurrency = 2
  # Set a 6 second maximum poll interval for the consumer
  config.kafka[:'session.timeout.ms'] = '6000'
  config.kafka[:'max.poll.interval.ms'] = '6000'
end

setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic
  end
end

class Job < ActiveJob::Base
  queue_as DataCollector.topic

  karafka_options(
    dispatch_method: :produce_sync,
    timeout: 8000
  )

  def perform(value1)
    sleep(7) # Intentionally take longer than the maximum poll interval
    DataCollector.data[0] << value1
  end
end

VALUE1 = rand

Job.perform_later(VALUE1)

# This gives at least one second for another consumption of the message based on the sleep
eight_seconds_later = 8.seconds.from_now

start_karafka_and_wait_until do
  Time.now > eight_seconds_later
end

aj_config = Karafka::App.config.internal.active_job

assert_equal aj_config.dispatcher.class, Karafka::ActiveJob::Dispatcher
assert_equal aj_config.job_options_contract.class, Karafka::ActiveJob::JobOptionsContract
assert_equal VALUE1, DataCollector.data[0][0]
assert_equal 1, DataCollector.data[0].size
