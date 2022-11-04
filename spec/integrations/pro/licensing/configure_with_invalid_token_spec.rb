# frozen_string_literal: true

# Karafka should not start if the token is invalid

failed_as_expected = false

begin
  setup_karafka do |config|
    config.license.token = rand.to_s
  end
rescue Karafka::Errors::InvalidLicenseTokenError
  failed_as_expected = true
end

assert failed_as_expected
assert_equal false, Karafka.pro?

# Pro components should not be visible
assert_equal false, const_visible?('Karafka::Pro::Processing::StrategySelector')
assert_equal false, const_visible?('Karafka::Pro::Processing::Partitioner')
assert_equal false, const_visible?('Karafka::Pro::Processing::Coordinator')
assert_equal false, const_visible?('Karafka::Pro::BaseConsumer')
assert_equal false, const_visible?('Karafka::Pro::Processing::JobsBuilder')
assert_equal false, const_visible?('Karafka::Pro::Routing::Features::LongRunningJob::Topic')
assert_equal false, const_visible?('Karafka::Pro::Routing::Features::LongRunningJob::Contract')
assert_equal false, const_visible?('Karafka::Pro::Routing::Features::LongRunningJob::Config')
assert_equal false, const_visible?('Karafka::Pro::Routing::Features::VirtualPartitions::Topic')
assert_equal false, const_visible?('Karafka::Pro::Routing::Features::VirtualPartitions::Contract')
assert_equal false, const_visible?('Karafka::Pro::Routing::Features::VirtualPartitions::Config')
assert_equal false, const_visible?('Karafka::Pro::Processing::Jobs::ConsumeNonBlocking')
assert_equal false, const_visible?('Karafka::Pro::ActiveJob::Consumer')
assert_equal false, const_visible?('Karafka::Pro::ActiveJob::Dispatcher')
assert_equal false, const_visible?('Karafka::Pro::ActiveJob::JobOptionsContract')
assert_equal false, const_visible?('Karafka::Pro::PerformanceTracker')
assert_equal false, const_visible?('Karafka::Pro::Processing::Scheduler')
