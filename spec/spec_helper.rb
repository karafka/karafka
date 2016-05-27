ENV['KARAFKA_ENV'] = 'test'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

%w(
  rubygems
  simplecov
  rake
  logger
  poseidon
  timecop
).each do |lib|
  require lib
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
      config.kafka.hosts = ['localhost:9092']
      config.zookeeper.hosts = ['localhost:2181']
      config.wait_timeout = 10 # 10 seconds
      config.max_concurrency = 1 # 1 thread for specs
      config.name = rand.to_s
      config.redis = {}
    end
  end
end
