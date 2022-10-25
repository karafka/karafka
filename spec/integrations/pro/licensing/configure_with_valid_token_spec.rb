# frozen_string_literal: true

# Pro components should be loaded when we run in pro mode and a nice message should be printed

LOGS = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(LOGS)
  config.license.token = pro_license_token
end

LOGS.rewind

logs = LOGS.read
config = Karafka::App.config.internal
pro = Karafka::Pro

assert_equal false, logs.include?('] ERROR -- : Your license expired')
assert_equal false, logs.include?('Please reach us')
assert Karafka.pro?
assert const_visible?('Karafka::Pro::Processing::Coordinator')
assert const_visible?('Karafka::Pro::Processing::Partitioner')
assert const_visible?('Karafka::Pro::BaseConsumer')
assert const_visible?('Karafka::Pro::Processing::JobsBuilder')
assert const_visible?('Karafka::Pro::Processing::Scheduler')
assert const_visible?('Karafka::Pro::Routing::Features::LongRunningJob::Topic')
assert const_visible?('Karafka::Pro::Routing::Features::LongRunningJob::Contract')
assert const_visible?('Karafka::Pro::Routing::Features::LongRunningJob::Config')
assert const_visible?('Karafka::Pro::Routing::Features::VirtualPartitions::Topic')
assert const_visible?('Karafka::Pro::Routing::Features::VirtualPartitions::Contract')
assert const_visible?('Karafka::Pro::Routing::Features::VirtualPartitions::Config')
assert const_visible?('Karafka::Pro::Processing::Jobs::ConsumeNonBlocking')
assert const_visible?('Karafka::Pro::ActiveJob::Consumer')
assert const_visible?('Karafka::Pro::ActiveJob::Dispatcher')
assert const_visible?('Karafka::Pro::ActiveJob::JobOptionsContract')
assert const_visible?('Karafka::Pro::PerformanceTracker')
assert_equal pro::Processing::Partitioner, config.processing.partitioner_class
assert_equal pro::Processing::Coordinator, config.processing.coordinator_class
assert_equal pro::Processing::Scheduler, config.processing.scheduler.class
assert_equal pro::Processing::JobsBuilder, config.processing.jobs_builder.class
assert_equal pro::ActiveJob::Dispatcher, config.active_job.dispatcher.class
assert_equal pro::ActiveJob::Consumer, config.active_job.consumer_class
assert_equal pro::ActiveJob::JobOptionsContract, config.active_job.job_options_contract.class
