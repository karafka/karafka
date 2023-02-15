# frozen_string_literal: true

# Karafka should update the cached references to the monitor, logger and producer once those are
# altered during the configuration

::Karafka.logger
post_logger = ::Karafka::Instrumentation::Logger.new

::Karafka.monitor
post_monitor = ::Karafka::Instrumentation::Monitor.new

::Karafka.producer
post_producer = Object.new

Karafka::App.setup do |config|
  config.logger = post_logger
  config.monitor = post_monitor
  config.producer = post_producer
end

assert_equal ::Karafka.logger, post_logger
assert_equal ::Karafka.monitor, post_monitor
assert_equal ::Karafka.producer, post_producer
