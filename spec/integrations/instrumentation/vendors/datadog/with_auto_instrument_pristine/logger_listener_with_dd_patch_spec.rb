# frozen_string_literal: true

# When `datadog/auto_instrument` patches Karafka and the Karafka Datadog LoggerListener is
# subscribed as well, the listener should finish its own span for each job, so jobs do not nest
# into one never-ending trace. It should also warn once about the duplicated tracing.

Bundler.require(:default)

require "tempfile"
require "datadog/auto_instrument"

Datadog.configure do |c|
  c.tracing.test_mode.enabled = true
  c.logger.level = Logger::FATAL
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV["KARAFKA_BOOT_FILE"] = dummy_boot_file

strio = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(strio)
  config.concurrency = 1
  config.max_messages = 1
end

require "karafka/instrumentation/vendors/datadog/logger_listener"

trace_listener = Karafka::Instrumentation::Vendors::Datadog::LoggerListener.new do |config|
  config.client = Datadog::Tracing
end

Karafka.monitor.subscribe(trace_listener)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:traces] << Datadog::Tracing.active_trace&.id
  end
end

draw_routes(Consumer)
produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:traces].size >= 10
end

assert Datadog::Tracing::Contrib::Karafka::Patcher.patched?
assert !DT[:traces].include?(nil), DT[:traces]
assert_equal DT[:traces].size, DT[:traces].uniq.size, DT[:traces]
assert_equal 1, strio.string.scan("dd-trace-rb Karafka integration is active").size
