%w(
  rake
  rubygems
  bundler
  pathname
  timeout
  logger
  poseidon
  poseidon_cluster
  sidekiq
  sidekiq_glass
  active_support/callbacks
  active_support/core_ext/hash/indifferent_access
  karafka/loader
).each { |lib| require lib }

ENV['KARAFKA_ENV'] ||= 'development'

# Karafka library
module Karafka
  class << self
    attr_writer :logger

    # @return [Logger] logger that we want to use
    def logger
      @logger ||= ::Karafka::Logger.build
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

    # @return [String] string with current environment
    def env
      ENV['KARAFKA_ENV'] || 'development'
    end
  end
end

Karafka::Loader.new.load!(Karafka.core_root)

load 'karafka/tasks/karafka.rake'
