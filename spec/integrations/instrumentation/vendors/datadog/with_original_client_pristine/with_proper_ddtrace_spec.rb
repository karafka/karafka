# frozen_string_literal: true

# This spec ensures, we do not use by accident ActiveSupport methods when working with listeners
# @see https://github.com/karafka/karafka/pull/1624

# To be removed when DD supports Ruby 3.4
# @see https://github.com/karafka/karafka/issues/2387
CURRENT_VERSION = Gem::Version.new(RUBY_VERSION)
DD_MIN_NOT_SUPPORTED = Gem::Version.new('3.4.0')

exit 0 if CURRENT_VERSION >= DD_MIN_NOT_SUPPORTED

Bundler.require(:default)

require 'tempfile'
require 'ddtrace'
require 'datadog/statsd'

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

setup_karafka

require 'karafka/instrumentation/vendors/datadog/logger_listener'

trace_listener = ::Karafka::Instrumentation::Vendors::Datadog::LoggerListener.new do |config|
  config.client = Datadog::Tracing
end

Karafka.monitor.subscribe(trace_listener)

require 'karafka/instrumentation/vendors/datadog/metrics_listener'
listener = ::Karafka::Instrumentation::Vendors::Datadog::MetricsListener.new do |config|
  config.client = Datadog::Statsd.new('localhost', 8125)
  # Publish host as a tag alongside the rest of tags
  config.default_tags = ["host:#{Socket.gethostname}"]
end

Karafka.monitor.subscribe(listener)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes(Consumer)
produce(DT.topic, '1')

start_karafka_and_wait_until do
  DT.key?(0)
end
