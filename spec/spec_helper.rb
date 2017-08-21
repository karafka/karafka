# frozen_string_literal: true

ENV['KARAFKA_ENV'] = 'test'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

%w[
  simplecov
  timecop
  fiddle
  tempfile
].each do |lib|
  require lib
end

# Some object patches are here
class Object
  # This is a workaround class for thor patches, so it won' bother us
  # with nonexisting method namespace (that we don't use)
  def namespace
    raise
  end
end

# @return [Boolean] true if we run against jruby
def jruby?
  ENV['RUBY_VERSION'].include?('jruby')
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

Timecop.safe_mode = true

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.disable_monkey_patching!

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
      config.kafka.seed_brokers = ['localhost:9092']
      config.client_id = rand.to_s
      config.redis = { url: 'redis://' }
      config.kafka.offset_retention_time = -1
      config.kafka.max_bytes_per_partition = 1_048_576
      config.kafka.start_from_beginning = true
    end
  end
end
