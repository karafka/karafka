# frozen_string_literal: true

ENV['KARAFKA_ENV'] = 'test'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

%w[
  byebug
  active_support
  singleton
  factory_bot
  fiddle
  ostruct
  simplecov
  tempfile
  zlib
  fugit
].each do |lib|
  require lib
end

# Are we running regular specs or pro specs
SPECS_TYPE = ENV.fetch('SPECS_TYPE', 'default')

# Don't include unnecessary stuff into rcov
SimpleCov.start do
  add_filter '/vendor/'
  add_filter '/gems/'
  add_filter '/.bundle/'
  add_filter '/doc/'
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/lib/karafka/railtie'
  add_filter '/lib/karafka/patches'
  # We do not spec strategies here. We do it via integration test suite
  add_filter '/lib/karafka/cli/topics/align'
  add_filter '/lib/karafka/cli/topics/base'
  add_filter '/lib/karafka/cli/topics/plan'
  add_filter '/processing/strategies'
  # Consumers are tested in integrations
  add_filter '/consumer'
  # CLI commands are also checked via integrations
  add_filter '/cli/topics.rb'
  add_filter '/vendors/'

  # enable_coverage :branch
  command_name [SPECS_TYPE, ARGV].flatten.join('-')
  merge_timeout 3600
end

# Require total coverage after running both regular and pro
SimpleCov.minimum_coverage(93.6) if SPECS_TYPE == 'pro'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"]
  .sort
  .each { |f| require f }

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.disable_monkey_patching!
  config.order = :random

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.before do |example|
    # When we test things, we subscribe sometimes with one-off monitors, they need to always be
    # cleared not to spam and break test-suit
    Karafka.monitor.notifications_bus.clear

    next unless example.metadata[:type] == :pro

    Karafka::Pro::Loader.pre_setup_all(Karafka::App.config)
  end

  config.after do
    Karafka::App.routes.clear
    Karafka.monitor.notifications_bus.clear
    Karafka::App.config.internal.routing.activity_manager.clear
    Karafka::Processing::InlineInsights::Tracker.clear
  end

  config.after(:suite) do
    PRODUCERS.regular.close
    PRODUCERS.transactional.close
  end
end

require 'karafka'
require 'active_job/karafka'
require 'karafka/pro/loader'

# This will make all the pro components visible but will not use them anywhere
Karafka::Pro::Loader.require_all if ENV['SPECS_TYPE'] == 'pro'

# We extend this manually since it's done by a Railtie that we do not run here
ActiveJob::Base.extend ::Karafka::ActiveJob::JobExtensions

# Test setup for the framework
module Karafka
  # Configuration for test env
  class App
    setup do |config|
      config.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
      config.client_id = rand.to_s
      config.pause_timeout = 1
      config.pause_max_timeout = 1
      config.pause_with_exponential_backoff = false
    end
  end
end

RSpec.extend RSpecLocator.new(__FILE__)

# Alias for two producers that we need in specs. Regular one that is not transactional and the
# other one that is transactional for transactional specs
PRODUCERS = OpenStruct.new(
  regular: Karafka.producer,
  transactional: ::WaterDrop::Producer.new do |p_config|
    p_config.kafka = ::Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
    p_config.kafka[:'transactional.id'] = SecureRandom.uuid
    p_config.logger = Karafka::App.config.logger
  end
)

# We by default use the default listeners for specs to check how they work and that
# they don't not break anything
Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

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

# Some operations in Kafka, like topics creation can finish successfully but cluster on a loaded
# machine may still perform some internal operations. In such cases, when using transactional
# producer, state may be refreshed during transaction causing critical errors.
#
# We can run this when waiting is needed to ensure state stability.
def wait_if_needed
  return unless ENV.key?('CI')

  sleep(1)
end

# We need to clear argv because otherwise we would get reports on invalid options for CLI specs
ARGV.clear
