# frozen_string_literal: true

%w[
  delegate
  English
  waterdrop
  kafka
  envlogic
  json
  thor
  forwardable
  fileutils
  concurrent
  dry-configurable
  dry-validation
  dry/events/publisher
  dry/inflector
  dry/monitor/notifications
  dry/core/constants
  zeitwerk
].each(&method(:require))

unless ENV.key?('I_ACCEPT_CRITICAL_ERRORS_IN_KARAFKA_1_4')
  3.times { puts }
  puts '~' * 50
  puts "~~~ \033[31mCRITICAL\033[0m NOTICE ON KARAFKA 1.4 reliability ~~~"
  puts '~' * 50
  puts
  puts 'Karafka 1.4 is no longer supported and contains critical errors, included but not limited to:'
  puts
  puts '  - Double processing of messages'
  puts '  - Skipping messages'
  puts '  - Hanging during processing'
  puts '  - Unexpectedly stopping message processing'
  puts '  - Failure to deliver messages to Kafka'
  puts '  - Resetting the consumer group and starting from the beginning'
  puts
  puts 'To resolve these issues, it is highly recommended to upgrade to Karafka 2.1 or higher.'
  puts
  puts 'If you want to ignore this message and continue, set the I_ACCEPT_CRITICAL_ERRORS_IN_KARAFKA_1_4 env variable to true.'
  puts
  puts 'Apologies for any inconvenience caused by this release.'
  puts 'There is no other way to make sure, that you are notified about those issues and their severity.'
  puts
  puts 'If you need help with the upgrade, we do have a Slack channel you can join: https://slack.karafka.io/'
  puts
  puts '~' * 50
  puts

  raise RuntimeError
end

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

Zeitwerk::Loader
  .for_gem
  .tap(&:setup)
  .tap(&:eager_load)

Kafka::Consumer.prepend(Karafka::Patches::RubyKafka)
