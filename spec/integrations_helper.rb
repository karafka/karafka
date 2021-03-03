# frozen_string_literal: true

# This helper content is being used only in the forked integration tests processes.

ENV['KARAFKA_ENV'] = 'test'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

require 'singleton'
require 'securerandom'
require 'byebug'
require 'lib/karafka'
require 'spec/support/data_collector'

Thread.abort_on_exception = true

# Test setup for the framework
def setup_karafka
  Karafka::App.setup do |config|
    # Use some decent defaults
    config.kafka = { 'bootstrap.servers' => '127.0.0.1:9092' }
    config.client_id = caller_locations(1..1).first.path.split('/').last
    config.pause_timeout = 1
    config.pause_max_timeout = 1
    config.pause_with_exponential_backoff = false
    config.max_wait_time = 500
    config.shutdown_timeout = 30_000
    config.producer = ::WaterDrop::Producer.new do |producer_config|
      producer_config.kafka = config.kafka
      producer_config.logger = config.logger
      # We need to wait a lot sometimes because we create a lot of new topics and this can take
      # time
      producer_config.max_wait_timeout = 120 # 2 minutes
    end

    # Allows to overwrite any option we're interested in
    yield(config) if block_given?
  end

  Karafka.logger.level = 'debug'

  Karafka.monitor.subscribe(Karafka::Instrumentation::StdoutListener.new)
  Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

  Karafka::App.boot!
end

# Waits until block yields true
def wait_until
  sleep(0.01) until yield

  Karafka::Server.stop

  # Give it enough time to start the stopping process before everything stops
  # For some tasks where this code does not run in a background thread we might stop whole process
  # too fast, not giving Karafka (in a background thread) enough time to do all the things
  sleep(5)
end

# Starts Karafka and waits until the block evaluates to true. Then it stops Karafka.
def start_karafka_and_wait_until(&block)
  Thread.new { wait_until(&block) }

  Karafka::Server.run
end

# Sends data to Kafka in a sync way
# @param topic [String] topic name
# @param payload [String] data we want to send
# @param details [Hash] other details
def produce(topic, payload, details = {})
  Karafka::App.producer.produce_sync(
    **details.merge(
      topic: topic,
      payload: payload
    )
  )
end

# Two basic helpers for assertion checking. Since we use only those, it was not worth adding
# another gem

AssertionFailedError = Class.new(StandardError)

# Checks that what we've received and expected is equal
#
# @param expected [Object] what we expect
# @param received [Object] what we've received
def assert_equal(expected, received)
  return if expected == received

  raise AssertionFailedError, "#{received} does not equal to #{expected}"
end

# Checks that what we've received and what we do not expect is not equal
#
# @param not_expected [Object] what we do not expect
# @param received [Object] what we've received
def assert_not_equal(not_expected, received)
  return if not_expected != received

  raise AssertionFailedError, "#{received} equals to #{not_expected}"
end
