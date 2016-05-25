%w(
  rake
  ostruct
  rubygems
  bundler
  English
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
  fileutils
  dry-configurable
  active_support/callbacks
  active_support/core_ext/class/subclasses
  active_support/core_ext/hash/indifferent_access
  active_support/descendants_tracker
  active_support/inflector
  karafka/loader
  karafka/status
).each { |lib| require lib }

# Karafka library
module Karafka
  extend Envlogic

  class << self
    # @return [Logger] logger that we want to use. Will use ::Karafka::Logger by default
    def logger
      @logger ||= App.config.logger
    end

    # @return [::Karafka::Monitor] monitor that we want to use. Will use dummy monitor by default
    def monitor
      @monitor ||= App.config.monitor
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
      Pathname.new(ENV['KARAFKA_BOOT_FILE'] || File.join(Karafka.root, 'app.rb'))
    end
  end
end

Karafka::Loader.new.load!(Karafka.core_root)
