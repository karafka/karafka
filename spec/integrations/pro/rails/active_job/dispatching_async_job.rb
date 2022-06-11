# frozen_string_literal: true

# Karafka should be able to dispatch jobs using async pro adapter

setup_karafka do |config|
  config.license.token = pro_license_token
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
    dispatch_method: :produce_async
  )

  def perform(value1, value2)
    DataCollector[0] << value1
    DataCollector[0] << value2
  end
end

VALUE1 = rand
VALUE2 = rand

Job.perform_later(VALUE1, VALUE2)

start_karafka_and_wait_until do
  DataCollector[0].size >= 1
end

aj_config = Karafka::App.config.internal.active_job

assert_equal aj_config.consumer, Karafka::Pro::ActiveJob::Consumer
assert_equal aj_config.dispatcher.class, Karafka::Pro::ActiveJob::Dispatcher
assert_equal aj_config.job_options_contract.class, Karafka::Pro::ActiveJob::JobOptionsContract
assert_equal VALUE1, DataCollector[0][0]
assert_equal VALUE2, DataCollector[0][1]
assert_equal 1, DataCollector.data.size
