# frozen_string_literal: true

# When librdkafka reports an error (here: no broker under the configured address), the default
# LoggerListener should log the error with only the top two backtrace lines, not the whole
# polling loop stack

# Collects all the error level log entries so we can inspect what the listener wrote
class CapturingLogger < Logger
  attr_reader :errors

  def initialize
    super(File::NULL)
    @errors = []
  end

  def error(message = nil, &)
    @errors << message
    super
  end
end

logger = CapturingLogger.new

setup_karafka(allow_errors: true) do |config|
  # Bad port on purpose to trigger the error
  config.kafka = { "bootstrap.servers": "127.0.0.1:9090" }
  config.logger = logger
end

draw_routes(Class.new(Karafka::BaseConsumer), create_topics: false)

prefix = "librdkafka internal error occurred:"

start_karafka_and_wait_until do
  index = logger.errors.index { |entry| entry.to_s.start_with?(prefix) }
  index && logger.errors.size > index + 1
end

index = logger.errors.index { |entry| entry.to_s.start_with?(prefix) }
backtrace = logger.errors[index + 1].to_s.split("\n")

assert_equal 2, backtrace.size
assert backtrace.first.include?("/rdkafka/"), backtrace
assert backtrace.none? { |line| line.include?("fetch_loop") }, backtrace
