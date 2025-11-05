# frozen_string_literal: true

# This helper content is being used only in the forked integration tests processes.

unless ENV.key?('PRISTINE_MODE')
  Warning[:performance] = true if RUBY_VERSION >= '3.3'
  Warning[:deprecated] = true
  $VERBOSE = true

  require 'warning'

  Warning.process do |warning|
    next unless warning.include?(Dir.pwd)
    # Filter out warnings we don't care about in specs
    next if warning.include?('_spec')
    # We redefine whole bunch of stuff to simulate various scenarios
    next if warning.include?('previous definition of')
    next if warning.include?('method redefined')
    next if warning.include?('vendor/')
    # Multi-delegator redefining is expected
    next if warning.include?('multi_delegator.rb')
    # We redefine it on purpose
    next if warning.include?('fixture_file')

    raise "Warning in your code: #{warning}"
  end
end

ENV['KARAFKA_ENV'] = 'test'

unless ENV['PRISTINE_MODE']
  require 'bundler'
  Bundler.setup(:default, :test, :integrations)
  require_relative '../lib/karafka'
  require 'byebug'
end

require 'singleton'
require 'securerandom'
require 'stringio'
require 'tmpdir'
require_relative 'support/data_collector'
require_relative 'support/duplications_detector'

Thread.abort_on_exception = true

# Make sure all logs are always flushed
$stdout.sync = true

# Alias data collector for shorter referencing
DT = DataCollector

# Test setup for the framework
# @param allow_errors [true, false, Array<String>] Should we allow any errors (true), none (false)
#   or a given types (array with types)
# @param pro [Boolean] is it a pro spec
# @param log_messages [Boolean] should we log payloads in WaterDrop for the default producer
# @param consumer_group_protocol [Boolean] use KIP-848 consumer group protocol
def setup_karafka(
  allow_errors: false,
  # automatically load pro for all the pro specs unless stated otherwise
  pro: caller_locations(1..1).first.path.include?('integrations/pro/'),
  log_messages: true,
  consumer_group_protocol: false
)
  # If the spec  is in pro, run in pro mode
  become_pro! if pro

  Karafka::App.setup do |config|
    config.kafka = {
      'bootstrap.servers': '127.0.0.1:9092',
      'statistics.interval.ms': 100,
      # We need to send this often as in specs we do time sensitive things and we may be kicked
      # out of the consumer group if it is not delivered fast enough
      'heartbeat.interval.ms': 1_000,
      'queue.buffering.max.ms': 5,
      'partition.assignment.strategy': 'range,roundrobin'
    }
    config.client_id = DT.consumer_group
    # Prevents conflicts when running in parallel
    config.group_id = DT.consumer_group
    config.pause.timeout = 1
    config.pause.max_timeout = 1
    config.pause.with_exponential_backoff = false
    config.max_wait_time = 500
    config.shutdown_timeout = 30_000
    config.swarm.nodes = 2
    config.internal.connection.reset_backoff = 1_000

    # Allows to overwrite any option we're interested in
    yield(config) if block_given?

    # Apply KIP-848 consumer group protocol configuration if requested
    if consumer_group_protocol
      config.kafka[:'group.protocol'] = 'consumer'
      config.kafka.delete(:'partition.assignment.strategy')
      config.kafka.delete(:'heartbeat.interval.ms')
    end

    # Configure producer once everything else has been configured
    config.producer = WaterDrop::Producer.new do |producer_config|
      producer_config.kafka = Karafka::Setup::AttributesMap.producer(config.kafka.dup)
      producer_config.logger = config.logger
      # We need to wait a lot sometimes because we create a lot of new topics and this can take
      # time
      producer_config.max_wait_timeout = 120_000 # 2 minutes
    end

    # This will ensure, that the recurring tasks data does not leak in between tests (if needed)
    if Karafka.pro?
      # Do not redefine topics locations if re-configured
      unless @setup_karafka_first_run
        config.recurring_tasks.group_id = "rt-#{SecureRandom.uuid}"
        config.recurring_tasks.topics.schedules.name = "it-#{SecureRandom.uuid}"
        config.recurring_tasks.topics.logs.name = "it-#{SecureRandom.uuid}"
        # Run often so we do not wait on the first run
        config.recurring_tasks.interval = 1_000

        config.scheduled_messages.interval = 1_000
      end

      config.recurring_tasks.producer = Karafka.producer
    end
  end

  Karafka.logger.level = 'debug'

  unless @setup_karafka_first_run
    # We turn on all the instrumentation just to make sure it works also in the integration specs
    Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
    Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)
  end

  # We turn on also WaterDrop instrumentation the same way and for the same reasons as above
  listener = WaterDrop::Instrumentation::LoggerListener.new(
    Karafka.logger,
    log_messages: log_messages
  )

  Karafka.producer.monitor.subscribe(listener)

  # Ensure there are no duplicates in the fetched data
  Karafka::App.monitor.subscribe(DuplicationsDetector.new(self))

  return if allow_errors == true

  # For integration specs where we do not expect any errors, we can set this and it will
  # immediately exit when any error occurs in the flow
  # There are some specs where we want to allow only a particular type of error, then we can set
  # it explicitly
  Karafka::App.monitor.subscribe('error.occurred') do |event|
    # This allows us to specify errors we expect while not ignoring others
    next if allow_errors.is_a?(Array) && allow_errors.include?(event[:type])

    # Print error event details in case we are going to exit
    Karafka.logger.fatal event[:error]

    # This sleep buys us some time before exit so logs are flushed
    sleep(0.5)

    exit! 8
  end
ensure
  @setup_karafka_first_run = true
end

# Loads the web UI for integration specs of tracking
# @param migrate [Boolean] should we migrate and create topics. Defaults to true
def setup_web(migrate: true)
  require 'karafka/web'

  # Use new groups and topics for each spec, so we don't end up with conflicts
  Karafka::Web.setup do |config|
    config.group_id = "it-#{SecureRandom.uuid}"
    config.topics.consumers.reports.name = "it-#{SecureRandom.uuid}"
    config.topics.consumers.states.name = "it-#{SecureRandom.uuid}"
    config.topics.consumers.metrics.name = "it-#{SecureRandom.uuid}"
    config.topics.consumers.commands.name = "it-#{SecureRandom.uuid}"
    config.topics.errors.name = "it-#{SecureRandom.uuid}"

    yield(config) if block_given?
  end

  Karafka::Web.enable!

  return unless migrate

  Karafka::Web::Installer.new.migrate
end

# Configures the testing framework in a given spec and allows to run it inline (in the same file)
#
# @param framework [Symbol] framework we want to configure
def setup_testing(framework)
  if framework == :rspec
    require 'rspec'
    require 'rspec/autorun'
    require 'karafka/testing'
    require 'karafka/testing/rspec/helpers'

    RSpec.configure do |config|
      config.include Karafka::Testing::RSpec::Helpers

      config.disable_monkey_patching!
      config.order = :random

      config.expect_with :rspec do |expectations|
        expectations.include_chain_clauses_in_custom_matcher_descriptions = true
      end

      config.after do
        Karafka::App.routes.clear
        Karafka.monitor.notifications_bus.clear
        Karafka::App.config.internal.routing.activity_manager.clear
        Karafka::Processing::InlineInsights::Tracker.clear
      end
    end
  else
    raise
  end
end

# Switches specs into a Pro mode
def become_pro!
  # Do not become pro if already pro
  return if Karafka.pro?

  mod = Module.new do
    def self.token
      ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
    end
  end

  Karafka.const_set(:License, mod) unless Karafka.const_defined?(:License)
  require 'karafka/pro/loader'
  Karafka::Pro::Loader.require_all
  require_relative 'support/vp_stabilizer'
end

# Configures ActiveJob stuff in a similar way as the Railtie does for full Rails setup
def setup_active_job
  require 'active_job'
  require 'active_job/karafka'

  # This is done in Railtie but here we use only ActiveJob, not Rails
  ActiveJob::Base.extend Karafka::ActiveJob::JobExtensions
  ActiveJob::Base.queue_adapter = :karafka
end

# Sets up a raw rdkafka consumer
# @param options [Hash] rdkafka consumer options if we need to overwrite defaults
def setup_rdkafka_consumer(options = {})
  config = {
    'bootstrap.servers': '127.0.0.1:9092',
    'group.id': Karafka::App.consumer_groups.first.id,
    'auto.offset.reset': 'earliest',
    'enable.auto.offset.store': 'false',
    'partition.assignment.strategy': 'range,roundrobin'
  }.merge!(options)

  Rdkafka::Config.new(
    Karafka::Setup::AttributesMap.consumer(config)
  ).consumer
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

# Returns the next offset that we would consume if we would subscribe again
# @param topic [String] topic we are interested in
# @param normalize [Boolean]
# @param consumer_group_id [String]
# @return [Integer] next offset we would consume
#
# @note Please note, that for `latest` seek offset, -1 means from high-watermark. We simplify it
#   in our specs but it is worth keeping in mind.
def fetch_next_offset(
  topic = DT.topic,
  normalize: true,
  consumer_group_id: Karafka::App.consumer_groups.first.id
)
  results = Karafka::Admin.read_lags_with_offsets
  part_results = results.fetch(consumer_group_id).fetch(topic)[0]
  offset = part_results.fetch(:offset)

  return offset unless normalize

  offset.negative? ? 0 : offset
end

# @return [Array<Karafka::Routing::Topic>] all topics (declaratives and non-declaratives)
def fetch_routes_topics
  Karafka::App.routes.map { |route| route.topics.to_a }.flatten
end

# @return [Hash] hash with names of topics and configs as values or false for topics for which
#   we should use the defaults
def fetch_declarative_routes_topics_configs
  fetch_routes_topics.each_with_object({}) do |topic, accu|
    next unless topic.declaratives.active?

    accu[topic.name] ||= topic.declaratives

    next unless topic.dead_letter_queue?
    next unless topic.dead_letter_queue.topic

    # Setting to false will force defaults, useful when we do not want to declare DLQ topics
    # manually. This will ensure we always create DLQ topics if their details are not defined
    # in the routing
    accu[topic.name] ||= false
  end
end

# Creates topics defined in the routes so they are available for the specs
# Code below will auto-create all the routing based topics so we don't have to do it per spec
# If a topic is already created for example with more partitions, this will do nothing
#
# @note This code ensures that we do not create multiple topics from multiple tests at the same
#   time because under heavy creation load, Kafka hangs sometimes. Keep in mind, this lowers number
#   of topics created concurrently but some particular specs create topics on their own. The
#   quantity however should be small enough for Kafka to handle.
def create_routes_topics
  lock = File.open(File.join(Dir.tmpdir, 'create_routes_topics.lock'), File::CREAT | File::RDWR)
  lock.flock(File::LOCK_EX)

  # Create 3 topics in parallel to make specs bootstrapping faster
  fetch_declarative_routes_topics_configs.each_slice(3).to_a.each do |slice|
    slice.map do |name, config|
      args = if config
               [config.partitions, config.replication_factor, config.details]
             else
               [1, 1, {}]
             end

      # All integration tests topics names always have to start with it-
      unless name.start_with?('it-')
        puts 'All integration tests topics need to start with "it-"'
        puts "Attempt to create topic with name: #{name}"
        raise
      end

      Thread.new do
        Karafka::Admin.create_topic(
          name,
          *args
        )
      # Ignore if exists, some specs may try to create few times
      rescue Rdkafka::RdkafkaError => e
        e.code == :topic_already_exists ? nil : raise
      end
    end.each(&:join)
  end
ensure
  lock.close
end

# Waits until block yields true
# @param mode [Symbol] mode in which we are operating
# @param sleep [Float] how long to sleep between re-checks
def wait_until(mode: :server, sleep: 0.01)
  started_at = Time.now
  stop = false

  until stop
    stop = yield

    # Stop if it was running for 4 minutes and nothing changed
    # This prevent from hanging in case of specs instability
    if (Time.now - started_at) > 240
      puts DT.data
      raise StandardError, 'Execution expired'
    end

    sleep(sleep)
  end

  case mode
  when :server
    Karafka::Server.stop
  when :swarm
    Process.kill('TERM', Process.pid)
  else
    raise Karafka::Errors::UnsupportedCaseError, mode
  end

  # Give it enough time to start the stopping process before everything stops
  # For some tasks where this code does not run in a background thread we might stop whole process
  # too fast, not giving Karafka (in a background thread) enough time to do all the things
  sleep(5)
end

# Starts Karafka and waits until the block evaluates to true. Then it stops Karafka.
# @param mode [Symbol] `:server` or `:swarm` depending on how we want to run
# @param reset_status [Boolean] should we reset the server status to initializing after the
#   shutdown. This allows us to run server multiple times in the same process, making some
#   integration specs much easier to run
# @param sleep [Float] how long to sleep between re-checks. Useful when wanting to perform heavy
#   operations on checks but not to overload with them the process.
def start_karafka_and_wait_until(mode: :server, reset_status: false, sleep: 0.01, &block)
  Thread.new { wait_until(mode: mode, sleep: sleep, &block) }

  case mode
  when :server
    Karafka::Server.execution_mode.standalone!
    Karafka::Server.run
  when :swarm
    Karafka::Server.execution_mode.supervisor!
    Karafka::Swarm::Supervisor.new.run
  else
    raise Karafka::Errors::UnsupportedCaseError, mode
  end

  return unless reset_status

  Karafka::App.config.internal.status.reset!
  # Listeners have their own state and need to be moved back to be restarted
  Karafka::Server.listeners.each(&:pending!)
  # Since manager is for the whole lifecycle of the process, it needs to be re-created
  manager_class = Karafka::App.config.internal.connection.manager.class
  Karafka::App.config.internal.connection.manager = manager_class.new
end

# Sleeps until Karafka has an assignment on requested topics
# @param topics [Array<String>] list of topics for which assignments we wait
def wait_for_assignments(*topics)
  topics << DT.topic if topics.empty?

  unless @topics_assignments_subscribed
    Karafka.monitor.subscribe('statistics.emitted') do |event|
      next unless topics.all? do |topic|
        event[:statistics]['topics'].key?(topic)
      end

      DT[:topics_assignments_ready] = true
    end
  end

  # prevent re-subscribe in a loop
  @topics_assignments_subscribed = true

  sleep(0.1) until DT.key?(:topics_assignments_ready)

  # We wait after the assignment so we're sure polling have happened
  sleep(1)
end

# Sends data to Kafka in a sync way
# @param topic [String] topic name
# @param payload [String, nil] data we want to send
# @param details [Hash] other details
def produce(topic, payload, details = {})
  Karafka::App.producer.produce_sync(
    **details,
    topic: topic,
    payload: payload
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
# @param message [String] message we want to pass upon failure. If not present, the data
#   collector data will be printed
def assert_equal(expected, received, message = DT)
  return if expected == received

  raise AssertionFailedError, message || "#{received} does not equal to #{expected}"
end

# A shortcut to `assert_equal(true, value)` as often we check if something is true
# @param received [Boolean] true or false
# @param message [String] message we want to pass upon failure. If not present, the data
#   collector data will be printed
def assert(received, message = DT)
  assert_equal(true, received, message)
end

# Checks that what we've received and what we do not expect is not equal
#
# @param not_expected [Object] what we do not expect
# @param received [Object] what we've received
def assert_not_equal(not_expected, received)
  return if not_expected != received

  raise AssertionFailedError, "#{received} equals to #{not_expected}"
end

# Checks if two ranges do not overlap
#
# @param range_a [Range]
# @param range_b [Range]
def assert_no_overlap(range_a, range_b)
  assert(
    !(range_b.begin <= range_a.end && range_a.begin <= range_b.end),
    [range_a, range_b, DT]
  )
end

# @param file_path [String] path within fixtures dir to the expected file
# @return [String] fixture file content
def fixture_file(file_path)
  File.read(
    File.join(
      Karafka.gem_root,
      'spec',
      'support',
      'fixtures',
      file_path
    )
  )
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

# Captures stdout. Useful for specs that print out stuff that we want to check
def capture_stdout
  original_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = original_stdout
end
