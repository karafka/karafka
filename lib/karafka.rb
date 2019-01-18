# frozen_string_literal: true

%w[
  English
  waterdrop
  kafka
  envlogic
  thor
  forwardable
  fileutils
  multi_json
  require_all
  dry-configurable
  dry-validation
  dry/inflector
  dry/monitor/notifications
  active_support/callbacks
  karafka/loader
].each(&method(:require))

# Karafka library
module Karafka
  extend Envlogic

  class << self
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

%w[
  callbacks
  callbacks/*
  setup/dsl
  setup/config
  status
  schemas/config
  schemas/consumer_group_topic
  schemas/consumer_group
].each { |path| require_all File.join(Karafka.core_root, path + '.rb') }

Karafka::Loader.load!(Karafka.core_root)
Kafka::Consumer.prepend(Karafka::Patches::RubyKafka)
Dry::Configurable::Config.prepend(Karafka::Patches::DryConfigurable)
