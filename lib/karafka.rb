ENV['KARAFKA_ENV'] ||= 'development'

%w(
  rake
  rubygems
  bundler
  pathname
  timeout
  sidekiq
  poseidon
  aspector
  karafka/loader
).each { |lib| require lib }

# Karafka library
module Karafka
  def self.config
    Config.config
  end

  # @return [String] root path of this gem
  def self.gem_root
    Pathname.new(File.expand_path('../..', __FILE__))
  end

  # @return [String] app root path
  def self.root
    Pathname.new(File.dirname(ENV['BUNDLE_GEMFILE']))
  end

  # @return [String] path to sinatra core root
  def self.core_root
    Pathname.new(File.expand_path('../karafka', __FILE__))
  end
end

Karafka::Loader.new.load!(Karafka.core_root)

Karafka::Config.configure do |config|
  config.connection_pool_size = 20
  config.connection_pool_timeout = 1
  config.kafka_ports = %w( 9092 )
  config.kafka_host = '172.17.0.7'
  config.send_events = true
end
