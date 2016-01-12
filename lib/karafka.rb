%w(
  English
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
  thor
  active_support/callbacks
  active_support/descendants_tracker
  active_support/core_ext/hash/indifferent_access
  active_support/inflector
  karafka/loader
  karafka/status
).each { |lib| require lib }

# Karafka library
module Karafka
  extend Envlogic

  class << self
    attr_writer :logger, :monitor

    # This method is used to load all dynamically created/generated parts of Karafka framework
    # It is the last step that sets up every dynamic component of Karafka
    # @note This method must be executed after user application code is loaded
    def boot
      # This is tricky part to explain ;) but we will try
      # Each Karafka controller can have its own worker that will process in background
      # (or not if you really, really wish to). If you define them explicitly on a
      # controller level, they will be built automatically on first usage (lazy loaded)
      # Unfortunatelly Sidekiq (and other background processing engines) need to have workers
      # loaded, because when they do something like const_get(worker_name), they will get nil
      # instead of proper worker class
      Karafka::Routing::Mapper.controllers
      Karafka::Routing::Mapper.workers
    end

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

    # @return [String] Karafka app root path (user application path)
    def root
      Pathname.new(File.dirname(ENV['BUNDLE_GEMFILE']))
    end

    # @return [String] path to Karafka gem root core
    def core_root
      Pathname.new(File.expand_path('../karafka', __FILE__))
    end

    # @return [String] path to a default file that contains booting procedure etc
    # @note By default it is a file called 'app.rb' but it can be specified as you wish if you
    #   have Karafka that is merged into a Sinatra/Rails app and app.rb is taken.
    #   It will be used for console/workers/etc
    # @example Standard only-Karafka case
    #   Karafka.boot_file #=> '/home/app_path/app.rb'
    # @example Non standard case
    #   KARAFKA_BOOT_FILE='/home/app_path/karafka.rb'
    #   Karafka.boot_file #=> '/home/app_path/karafka.rb'
    def boot_file
      Pathname.new(
        ENV['KARAFKA_BOOT_FILE'] || File.join(Karafka.root, 'app.rb')
      )
    end
  end
end

Karafka::Loader.new.load!(Karafka.core_root)
