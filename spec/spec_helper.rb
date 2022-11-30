# frozen_string_literal: true

ENV['KARAFKA_ENV'] = 'test'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

%w[
  byebug
  factory_bot
  fiddle
  simplecov
  tempfile
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
  add_filter '/processing/strategies'

  # enable_coverage :branch
  command_name SPECS_TYPE
  merge_timeout 3600
end

# Require total coverage after running both regular and pro
SimpleCov.minimum_coverage(94) if SPECS_TYPE == 'pro'

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

  # When we test things, we subscribe sometimes with one-off monitors, they need to always be
  # cleared not to spam and break test-suit
  config.before { Karafka.monitor.notifications_bus.clear }

  config.after do
    Karafka::App.routes.clear
    Karafka.monitor.notifications_bus.clear
    Karafka::App.config.internal.routing.active.consumer_groups = []
    Karafka::App.config.internal.routing.active.subscription_groups = []
    Karafka::App.config.internal.routing.active.topics = []
  end

  config.before do |example|
    next unless example.metadata[:type] == :pro

    Karafka::Pro::Loader.setup(Karafka::App.config)
  end
end

require 'karafka'
require 'active_job/karafka'
require 'karafka/pro/loader'

# This will make all the pro components visible but will not use them anywhere
Karafka::Pro::Loader.require_all

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

# We by default use the default listeners for specs to check how they work and that
# they don't not break anything
Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)
