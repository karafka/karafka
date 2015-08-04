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
  class << self
    attr_writer :logger

    # @return [Logger] logger that we want to use
    def logger
      @logger ||= NullLogger
    end
    # @return [Karafka::Config] config instance
    def config
      Config.config
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
