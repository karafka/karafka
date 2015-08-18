%w(
  rake
  rubygems
  bundler
  pathname
  timeout
  sidekiq
  poseidon
  poseidon_cluster
  logger
  active_support/callbacks
  active_support/core_ext/hash/indifferent_access
).each { |lib| require lib }

%w(
  karafka/loader
).each { |lib| require lib }

ENV['KARAFKA_ENV'] ||= 'development'
ENV['KARAFKA_LOG_LEVEL'] = ::Logger::WARN.to_s if ENV['KARAFKA_ENV'] == 'production'
ENV['KARAFKA_LOG_LEVEL'] ||= ::Logger::DEBUG.to_s

# Karafka library
module Karafka
  class << self
    attr_writer :logger

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
