%w(
  rake
  rubygems
  bundler
  celluloid/current
  waterdrop
  pathname
  timeout
  logger
  poseidon
  poseidon_cluster
  sidekiq
  worker_glass
  envlogic
  active_support/callbacks
  active_support/descendants_tracker
  active_support/core_ext/hash/indifferent_access
  active_support/inflector
  karafka/loader
  karafka/status
  base64
).each { |lib| require lib }

# The Poseidon socket timeout is 10, so we give it a bit more time to shutdown after
# socket timeout
Celluloid.shutdown_timeout = 15

# Karafka library
module Karafka
  extend Envlogic

  class << self
    attr_writer :logger, :monitor

    # @return [Logger] logger that we want to use. Will use ::Karafka::Logger by default
    def logger
      @logger ||= ::Karafka::Logger.build
    end

    # @return [::Karafka::Monitor] monitor that we want to use. Will use dummy monitor by default
    def monitor
      @monitor ||= ::Karafka::Monitor.instance
    end

    # @return [String] root path of this gem
    def gem_root
      Pathname.new(File.expand_path('../..', __FILE__))
    end

    # @return [String] app root path
    def root
      Pathname.new(File.dirname(ENV['BUNDLE_GEMFILE']))
    end

    # @return [String] path to sinatra core root
    def core_root
      Pathname.new(File.expand_path('../karafka', __FILE__))
    end
  end
end

Karafka::Loader.new.load!(Karafka.core_root)

load 'karafka/tasks/karafka.rake'
load 'karafka/tasks/kafka.rake'
