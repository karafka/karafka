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
assert const_visible?('Karafka::Pro::BaseConsumer')
assert const_visible?('Karafka::Pro::Processing::JobsBuilder')
assert const_visible?('Karafka::Pro::Routing::Extensions')
assert const_visible?('Karafka::Pro::Processing::Jobs::ConsumeNonBlocking')
assert const_visible?('Karafka::Pro::ActiveJob::Consumer')
assert const_visible?('Karafka::Pro::ActiveJob::Dispatcher')
assert const_visible?('Karafka::Pro::ActiveJob::JobOptionsContract')
assert const_visible?('Karafka::Pro::PerformanceTracker')
assert const_visible?('Karafka::Pro::Scheduler')
assert_equal pro::Scheduler, config.scheduler.class
assert_equal pro::Processing::JobsBuilder, config.jobs_builder.class
assert_equal pro::ActiveJob::Dispatcher, config.active_job.dispatcher.class
assert_equal pro::ActiveJob::Consumer, config.active_job.consumer
assert_equal pro::ActiveJob::JobOptionsContract, config.active_job.job_options_contract.class
