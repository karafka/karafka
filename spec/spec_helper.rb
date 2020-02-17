# frozen_string_literal: true

ENV['KARAFKA_ENV'] = 'test'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

# @note HashWithIndifferentAccess is just for testing the optional integration,
# it is not used by default in the framework
%w[
  byebug
  factory_bot
  fiddle
  simplecov
  tempfile
].each do |lib|
  require lib
end

# @return [Boolean] true if we run against jruby
def jruby?
  (ENV['RUBY_VERSION'] || RUBY_ENGINE).include?('jruby')
end

# Don't include unnecessary stuff into rcov
SimpleCov.start do
  add_filter '/vendor/'
  add_filter '/gems/'
  add_filter '/.bundle/'
  add_filter '/doc/'
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/lib/karafka/tasks'
  merge_timeout 600
end

# jruby counts coverage a bit differently, so we ignore that
SimpleCov.minimum_coverage jruby? ? 95 : 100

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
end

require 'karafka'

# Test setup for the framework
module Karafka
  # Configuration for test env
  class App
    setup do |config|
      config.kafka.seed_brokers = ['kafka://localhost:9092']
      config.client_id = rand.to_s
      config.kafka.offset_retention_time = -1
      config.kafka.max_bytes_per_partition = 1_048_576
      config.kafka.start_from_beginning = true
    end
  end
end

# Set certificates path
CERTS_PATH = "#{File.dirname(__FILE__)}/support/certificates"

# In order to spec karafka out, we need to boot it first to initialize all the
# dynamic components
Karafka::App.boot!

# We by default use the default listeners for specs to check how they work and that
# they don't not break anything
Karafka.monitor.subscribe(WaterDrop::Instrumentation::StdoutListener.new)
Karafka.monitor.subscribe(Karafka::Instrumentation::StdoutListener.new)
Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)
