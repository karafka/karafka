# frozen_string_literal: true

%w[
  karafka-core
  delegate
  English
  rdkafka
  waterdrop
  json
  forwardable
  fileutils
  openssl
  optparse
  base64
  date
  singleton
  digest
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
      App.config.producer
    end

    # @return [::Karafka::Monitor] monitor that we want to use
    def monitor
      @monitor ||= App.config.monitor
    end

    # @return [Pathname] root path of this gem
    def gem_root
      Pathname.new(File.expand_path('..', __dir__))
    end

    # @return [Pathname] Karafka app root path (user application path)
    def root
      return @root if @root

      # If user points to a different root explicitly, use it
      if ENV['KARAFKA_ROOT_DIR']
        @root = Pathname.new(ENV['KARAFKA_ROOT_DIR'])

        return @root
      end

      # By default we infer the project root from bundler.
      # We cannot use the BUNDLE_GEMFILE env directly because it may be altered by things like
      # ruby-lsp. Instead we always fallback to the most outer Gemfile. In most of the cases, it
      # won't matter but in case of some automatic setup alterations like ruby-lsp, the location
      # from which the project starts may not match the original Gemfile.
      @root = Pathname.new(
        File.dirname(
          Bundler.with_unbundled_env { Bundler.default_gemfile }
        )
      )
    end

    # @return [Pathname] path to Karafka gem root core
    def core_root
      Pathname.new(File.expand_path('karafka', __dir__))
    end

    # @return [Boolean] true if there is a valid pro token present
    def pro?
      App.config.license.token != false
    end

    # @return [Boolean] Do we run within/with Rails. We use this to initialize Railtie and proxy
    #   the console invocation to Rails
    #
    # @note We allow users to disable Rails require because having Rails in the Gemfile does not
    #   always mean user wants to have it required. User may want to run Karafka without Rails
    #   even when having both in the same Gemfile.
    def rails?
      return @rails if instance_variable_defined?('@rails')

      @rails = Object.const_defined?('Rails::Railtie')

      # If Rails exists we set it immediately based on its presence and return
      return @rails if @rails

      # If rails is not present and user wants us not to force-load it, we return
      return @rails if ENV['KARAFKA_REQUIRE_RAILS'] == 'false'

      # If we should try to require it, we try and if no error, it means its there
      require('rails')

      @rails = true
    rescue LoadError
      @rails = false
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
      boot_file = Pathname.new(ENV['KARAFKA_BOOT_FILE'] || File.join(Karafka.root, 'karafka.rb'))

      return boot_file if boot_file.absolute?
      return boot_file if boot_file.to_s == 'false'

      Pathname.new(
        File.expand_path(
          boot_file,
          Karafka.root
        )
      )
    end

    # We need to be able to overwrite both monitor and logger after the configuration in case they
    # would be changed because those two (with defaults) can be used prior to the setup and their
    # state change should be reflected in the updated setup
    #
    # This method refreshes the things that might have been altered by the configuration
    def refresh!
      config = ::Karafka::App.config

      @logger = config.logger
      @producer = config.producer
      @monitor = config.monitor
    end
  end
end

loader = Zeitwerk::Loader.for_gem
# Do not load Rails extensions by default, this will be handled by Railtie if they are needed
loader.ignore(Karafka.gem_root.join('lib/active_job'))
# Do not load CurrentAttributes components as they will be loaded if needed
# @note We have to exclude both the .rb file as well as the whole directory so users can require
# current attributes only when needed
loader.ignore(Karafka.gem_root.join('lib/karafka/active_job/current_attributes'))
loader.ignore(Karafka.gem_root.join('lib/karafka/active_job/current_attributes.rb'))
# Do not load Railtie. It will load if after everything is ready, so we don't have to load any
# Karafka components when we require this railtie. Railtie needs to be loaded last.
loader.ignore(Karafka.gem_root.join('lib/karafka/railtie'))
# Do not load pro components as they will be loaded if needed and allowed
loader.ignore(Karafka.core_root.join('pro/'))
# Do not load vendors instrumentation components. Those need to be required manually if needed
loader.ignore(Karafka.core_root.join('instrumentation/vendors'))
loader.setup
loader.eager_load

# This will load features but since Pro are not loaded automatically, they will not be visible
# nor included here
::Karafka::Routing::Features::Base.load_all

# We need to detect and require (not setup) Pro components during the gem load, because we need
# to make pro components available in case anyone wants to use them as a base to their own
# custom components. Otherwise inheritance would not work.
Karafka::Licenser.detect do
  require 'karafka/pro/loader'

  Karafka::Pro::Loader.require_all
end

# Load railtie after everything else is ready so we know we can rely on it.
require 'karafka/railtie'

Karafka::Constraints.verify!
