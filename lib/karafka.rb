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
  openssl
  base64
  date
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

    # @return [WaterDrop::Producer] waterdrop messages producer
    def producer
      @producer ||= App.config.producer
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

    # @return [Boolean] true if there is a valid pro token present
    def pro?
      App.config.license.token != false
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

loader = Zeitwerk::Loader.for_gem
# Do not load Rails extensions by default, this will be handled by Railtie if they are needed
loader.ignore(Karafka.gem_root.join('lib/active_job'))
# Do not load pro components, this will be handled by license manager
loader.ignore(Karafka.gem_root.join('lib/karafka/pro'))
# Do not load vendors instrumentation components. Those need to be required manually if needed
loader.ignore(Karafka.gem_root.join('lib/karafka/instrumentation/vendors'))
loader.setup
loader.eager_load
