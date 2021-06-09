# frozen_string_literal: true

%w[
  delegate
  English
  rdkafka
  waterdrop
  json
  thor
  forwardable
  fileutils
  dry-configurable
  dry-validation
  dry/events/publisher
  dry/monitor/notifications
  zeitwerk
].each(&method(:require))

# Karafka framework main namespace
module Karafka
  class << self
    # @return [Karafka::Env] env instance that allows us to check environment
    def env
      @env ||= Env.new
    end

    # @param environment [String, Symbol] new environment that we want to set
    # @return [Karafka::Env] env instance
    # @example Assign new environment to Karafka::App
    #   Karafka::App.env = :production
    def env=(environment)
      env.replace(environment.to_s)
    end

    # @return [Logger] logger that we want to use. Will use ::Karafka::Logger by default
    def logger
      @logger ||= App.config.logger
    end

    # @return [::Karafka::Monitor] monitor that we want to use
    def monitor
      @monitor ||= App.config.monitor
    end

    # @return [String] root path of this gem
    def gem_root
      Pathname.new(File.expand_path('..', __dir__))
    end

    # @return [String] Karafka app root path (user application path)
    def root
      Pathname.new(ENV['KARAFKA_ROOT_DIR'] || File.dirname(ENV['BUNDLE_GEMFILE']))
    end

    # @return [String] path to Karafka gem root core
    def core_root
      Pathname.new(File.expand_path('karafka', __dir__))
    end

    # @return [String] path to a default file that contains booting procedure etc
    # @note By default it is a file called 'karafka.rb' but it can be specified as you wish if you
    #   have Karafka that is merged into a Sinatra/Rails app and karafka.rb is taken.
    #   It will be used for console/consumers/etc
    # @example Standard only-Karafka case
    #   Karafka.boot_file #=> '/home/app_path/karafka.rb'
    # @example Non standard case
    #   KARAFKA_BOOT_FILE='/home/app_path/app.rb'
    #   Karafka.boot_file #=> '/home/app_path/app.rb'
    def boot_file
      Pathname.new(ENV['KARAFKA_BOOT_FILE'] || File.join(Karafka.root, 'karafka.rb'))
    end
  end
end

Zeitwerk::Loader
  .for_gem
  .tap(&:setup)
  .tap(&:eager_load)
