# frozen_string_literal: true

# Karafka should not crash with expired token for non dev but should print an error message
# It also should work the way it works. We do not want to crash anyone processes running and
# for example restarting.
# It should aside from adding a message to logger also report an error into the monitor.

# Expired license behaves differently for development envs
Karafka.env = 'production'

LOGS = StringIO.new

Karafka::App.monitor.subscribe('error.occurred') do |event|
  assert_equal 'licenser.expired', event[:type]
  assert_equal Karafka::Errors::ExpiredLicenseTokenError, event[:error].class
  assert event[:error].message.include?('Your license expired on')
end

setup_karafka do |config|
  config.logger = Logger.new(LOGS)
  config.license.token = <<~TOKEN
    i6OS4XMugYjTxPUm4IIjyejEhQXnS/tzz4eSRThV1ebEYLbA6Y1x53XXsbRG
    Zx+DhTdosjH3RFmuy1J9LKVlYBa2WX9QGk6SGxVCCMiLUESnAj0VawsT20o/
    0Z22EFGkgoz9E/t1XdFAmCwYJOrns5tVtFjXIaCnSEaDnweCxLGDrk6fVYfB
    fkemJzii64BwyPlEqehIsbcH0F5rdiTonDJPtIwu36S1nuHCU/C269RQeyMc
    6UQ0n+8YfYJu8QIb5R0rnRiZQwF1jdW8IfjLRuLKi+7HQiNMjbcKoQohufsX
    xhiRyMJjMtRQpkKsFR1wrSaVXVpKMklfagXuwGioqhuy0lzWdAhNg/Vb4asG
    7FP2WbbcKJ44r36LJrHEIX4t1nuy9/Ee8RxTPxFPbEiaauDuSO4Ytzi9OkAC
    pW5tWnTrG9b1ARoS3u6hDo+OmK2t4dmk1x9RolAMUex1lwfP4Jyjj9Ff8a8U
    151nzgnqP3S4mq5zgY7lduowAUaw+wZ6
  TOKEN
end

LOGS.rewind

logs = LOGS.read
config = Karafka::App.config.internal
pro = Karafka::Pro

assert logs.include?('] ERROR -- : Your license expired on 2021-01-01')
assert logs.include?('Please reach us at contact@karafka.io')
assert Karafka.pro?

# We do not want to break systems, so even with expired keys, pro components should be loaded
assert const_visible?('Karafka::Pro::BaseConsumer')
assert const_visible?('Karafka::Pro::Processing::Coordinator')
assert const_visible?('Karafka::Pro::Processing::Partitioner')
assert const_visible?('Karafka::Pro::Processing::JobsBuilder')
assert const_visible?('Karafka::Pro::Routing::Extensions')
assert const_visible?('Karafka::Pro::Processing::Jobs::ConsumeNonBlocking')
assert const_visible?('Karafka::Pro::ActiveJob::Consumer')
assert const_visible?('Karafka::Pro::ActiveJob::Dispatcher')
assert const_visible?('Karafka::Pro::ActiveJob::JobOptionsContract')
assert const_visible?('Karafka::Pro::PerformanceTracker')
assert const_visible?('Karafka::Pro::Processing::Scheduler')
assert_equal pro::Processing::Scheduler, config.processing.scheduler.class
assert_equal pro::Processing::Coordinator, config.processing.coordinator_class
assert_equal pro::Processing::Partitioner, config.processing.partitioner_class
assert_equal pro::Processing::JobsBuilder, config.processing.jobs_builder.class
assert_equal pro::ActiveJob::Dispatcher, config.active_job.dispatcher.class
assert_equal pro::ActiveJob::Consumer, config.active_job.consumer_class
assert_equal pro::ActiveJob::JobOptionsContract, config.active_job.job_options_contract.class
