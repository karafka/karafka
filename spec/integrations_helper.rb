# frozen_string_literal: true

# This helper content is being used only in the forked integration tests processes.

ENV['KARAFKA_ENV'] = 'test'

unless ENV['PRISTINE_MODE']
  require 'bundler'
  Bundler.setup(:default, :test, :integrations)
  require_relative '../lib/karafka'
  require 'byebug'
end

require 'singleton'
require 'securerandom'
require_relative './support/data_collector'

Thread.abort_on_exception = true

# Make sure all logs are always flushed
$stdout.sync = true

# Alias data collector for shorter referencing
DT = DataCollector

# Test setup for the framework
def setup_karafka(allow_errors: false)
  Karafka::App.setup do |config|
    # Use some decent defaults
    caller_id = [caller_locations(1..1).first.path.split('/').last, SecureRandom.uuid].join('-')

    config.kafka = {
      'bootstrap.servers': '127.0.0.1:9092',
      'statistics.interval.ms': 100,
      # We need to send this often as in specs we do time sensitive things and we may be kicked
      # out of the consumer group if it is not delivered fast enough
      'heartbeat.interval.ms': 1_000,
      'queue.buffering.max.ms': 5
    }
    config.client_id = caller_id
    config.pause_timeout = 1
    config.pause_max_timeout = 1
    config.pause_with_exponential_backoff = false
    config.max_wait_time = 500
    config.shutdown_timeout = 30_000

    # Allows to overwrite any option we're interested in
    yield(config) if block_given?

    # Configure producer once everything else has been configured
    config.producer = ::WaterDrop::Producer.new do |producer_config|
      producer_config.kafka = Karafka::Setup::AttributesMap.producer(config.kafka.dup)
      producer_config.logger = config.logger
      # We need to wait a lot sometimes because we create a lot of new topics and this can take
      # time
      producer_config.max_wait_timeout = 120 # 2 minutes
    end
  end

  Karafka.logger.level = 'debug'

  # We turn on all the instrumentation just to make sure it works also in the integration specs
  Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
  Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

  # We turn on also WaterDrop instrumentation the same way and for the same reasons as above
  listener = ::WaterDrop::Instrumentation::LoggerListener.new(Karafka.logger)
  Karafka.producer.monitor.subscribe(listener)

  return if allow_errors == true

  # For integration specs where we do not expect any errors, we can set this and it will
  # immediately exit when any error occurs in the flow
  # There are some specs where we want to allow only a particular type of error, then we can set
  # it explicitly
  Karafka::App.monitor.subscribe('error.occurred') do |event|
    # This allows us to specify errors we expect while not ignoring others
    next if allow_errors.is_a?(Array) && allow_errors.include?(event[:type])

    # Print error event details in case we are going to exit
    Karafka.logger.fatal event

    # This sleep buys us some time before exit so logs are flushed
    sleep(0.5)

    exit! 8
  end
end

# Configures ActiveJob stuff in a similar way as the Railtie does for full Rails setup
def setup_active_job
  require 'active_job'
  require 'active_job/karafka'

  # This is done in Railtie but here we use only ActiveJob, not Rails
  ActiveJob::Base.extend ::Karafka::ActiveJob::JobExtensions
  ActiveJob::Base.queue_adapter = :karafka
end

# Sets up a raw rdkafka consumer
# @param options [Hash] rdkafka consumer options if we need to overwrite defaults
def setup_rdkafka_consumer(options = {})
  config = {
    'bootstrap.servers': 'localhost:9092',
    'group.id': Karafka::App.consumer_groups.first.id,
    'auto.offset.reset': 'earliest',
    'enable.auto.offset.store': 'false'
  }.merge!(options)

  Rdkafka::Config.new(
    Karafka::Setup::AttributesMap.consumer(config)
  ).consumer
end

# A simple helper for creation of topics with given partitions count. Single partition topics are
# automatically created during our specs, but for some we need more than one. In those cases we
# use this helper.
#
# The name is equal to the default spec topic, that is `DT.topic`
#
# @param name [String] topic name
# @param partitions [Integer] number of partitions for this topic
# @param config [Hash] optional topic configuration settings
def create_topic(name: DT.topic, partitions: 1, config: {})
  Karafka::Admin.create_topic(
    name,
    partitions,
    1,
    config
  )
end

# Sets up default routes (mostly used in integration specs) or allows to configure custom routes
# by providing a block
# @param consumer_class [Class, nil] consumer class we want to use if going with defaults
# @param create_topics [Boolean] should we create the defined topics (true by default)
# @param block [Proc] block with routes we want to draw if going with complex routes setup
def draw_routes(consumer_class = nil, create_topics: true, &block)
  Karafka::App.routes.draw do
    if block
      instance_eval(&block)
    else
      consumer_group DT.consumer_group do
        topic DT.topic do
          consumer consumer_class
        end
      end
    end
  end

  return unless create_topics

  create_routes_topics
end

# Creates topics defined in the routes so they are available for the specs
# Code below will auto-create all the routing based topics so we don't have to do it per spec
# If a topic is already created for example with more partitions, this will do nothing
def create_routes_topics
  topics_names = Set.new

  Karafka::App.routes.map(&:topics).flatten.each do |topics|
    topics.each { |topic| topics_names << topic.name }
  end

  topics_names.each { |topic_name| create_topic(name: topic_name) }
end

# Waits until block yields true
def wait_until
  started_at = Time.now
  stop = false

  until stop
    stop = yield

    # Stop if it was running for 2 minutes and nothing changed
    # This prevent from hanging in case of specs instability
    raise StandardError, 'Execution expired' if (Time.now - started_at) > 180

    sleep(0.01)
  end

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
# @param payload [String, nil] data we want to send
# @param details [Hash] other details
def produce(topic, payload, details = {})
  Karafka::App.producer.produce_sync(
    **details.merge(
      topic: topic,
      payload: payload
    )
  )
end

# Sends multiple messages to kafka efficiently
# @param topic [String] topic name
# @param payloads [Array<String, nil>] data we want to send
# @param details [Hash] other details
def produce_many(topic, payloads, details = {})
  messages = payloads.map { |payload| details.merge(topic: topic, payload: payload) }

  Karafka::App.producer.produce_many_sync(messages)
end

# Two basic helpers for assertion checking. Since we use only those, it was not worth adding
# another gem

AssertionFailedError = Class.new(StandardError)

# Checks that what we've received and expected is equal
#
# @param expected [Object] what we expect
# @param received [Object] what we've received
# @param message [nil, String] message we want to pass upon failure or nil if default should be
#   used
def assert_equal(expected, received, message = nil)
  return if expected == received

  raise AssertionFailedError, message || "#{received} does not equal to #{expected}"
end

# A shortcut to `assert_equal(true, value)` as often we check if something is true
# @param received [Boolean] true or false
# @param message [nil, String] message we want to pass upon failure
def assert(received, message = nil)
  assert_equal(true, received, message)
end

# @return [String] valid pro license token that we use in the integration tests
def pro_license_token
  ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
end

# Checks that what we've received and what we do not expect is not equal
#
# @param not_expected [Object] what we do not expect
# @param received [Object] what we've received
def assert_not_equal(not_expected, received)
  return if not_expected != received

  raise AssertionFailedError, "#{received} equals to #{not_expected}"
end

# Checks if a given constant can be accessed
# @param const_name [String] string with potential class / module name
# @return [Boolean] true if accessible
def const_visible?(const_name)
  Kernel.const_get(const_name)
  true
rescue NameError
  false
end
