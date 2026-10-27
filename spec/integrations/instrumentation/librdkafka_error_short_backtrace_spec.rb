# frozen_string_literal: true

# When librdkafka reports an error (here: no broker under the configured address), the default
# LoggerListener should log the error with only the top two backtrace lines, not the whole
# polling loop stack

strio = StringIO.new

setup_karafka(allow_errors: true) do |config|
  # Bad port on purpose to trigger the error
  config.kafka = { "bootstrap.servers": "127.0.0.1:9090" }
  config.logger = Logger.new(strio)
end

draw_routes(Class.new(Karafka::BaseConsumer), create_topics: false)

prefix = "librdkafka internal error occurred:"

# Each log entry starts with its severity header, while a multi-line backtrace continues on the
# following lines of the same entry
backtrace_after_error = lambda do
  entries = strio.string.split(/^(?=[DIWEFA], \[)/).map { |entry| entry.sub(/\A.*? -- : /, "") }
  index = entries.index { |entry| entry.start_with?(prefix) }

  index && entries[(index + 1)..].find { |entry| entry.start_with?("/") }
end

start_karafka_and_wait_until do
  backtrace_after_error.call
end

backtrace = backtrace_after_error.call.split("\n")

assert_equal 2, backtrace.size
assert backtrace.first.include?("/rdkafka/"), backtrace
assert backtrace.none? { |line| line.include?("fetch_loop") }, backtrace
