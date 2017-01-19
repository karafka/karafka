module Karafka
  # Module containing all Karafka setup related elements like configuration settings,
  # config validations and configurators for external gems integration
  module Setup
    # Configurator for setting up all the framework details that are required to make it work
    # @note If you want to do some configurations after all of this is done, please add to
    #   karafka/config a proper file (needs to inherit from Karafka::Setup::Configurators::Base
    #   and implement setup method) after that everything will happen automatically
    # @note This config object allows to create a 1 level nestings (nodes) only. This should be
    #   enough and will still keep the code simple
    # @see Karafka::Setup::Configurators::Base for more details about configurators api
    class Config
      extend Dry::Configurable

      # Available settings
      # option name [String] current app name - used to provide default Kafka groups namespaces
      setting :name
      # If inline_mode is set to true, we won't enqueue jobs, instead we will run them immediately
      setting :inline_mode, false
      # option logger [Instance] logger that we want to use
      setting :logger, ::Karafka::Logger.instance
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      setting :monitor, ::Karafka::Monitor.instance
      # option redis [Hash] redis options hash (url and optional parameters)
      # Note that redis could be rewriten using nested options, but it is a sidekiq specific
      # stuff and we don't want to touch it
      setting :redis
      # If batch_mode is true, incoming messages will be handled in batch, otherwsie one at a time.
      setting :batch_mode, false

      # Connection pool options are used for producer (Waterdrop)
      # They are configured automatically based on Sidekiq concurrency and number of routes
      # The bigger one is selected as we need to be able to send messages from both places
      setting :connection_pool do
        # Connection pool size for producers. Note that we take a bigger number because there
        # are cases when we might have more sidekiq threads than Karafka routes (small app)
        # or the opposite for bigger systems
        setting :size, -> { [::Karafka::App.routes.count, Sidekiq.options[:concurrency]].max }
        # How long should we wait for a working resource from the pool before rising timeout
        # With a proper connection pool size, this should never happen
        setting :timeout, 5
      end

      # option kafka [Hash] - optional - kafka configuration options (hosts)
      setting :kafka do
        # Array with at least one host
        setting :hosts
        # option session_timeout [Integer] the number of seconds after which, if a client
        #   hasn't contacted the Kafka cluster, it will be kicked out of the group.
        setting :session_timeout, 30
        # option offset_commit_interval [Integer] the interval between offset commits,
        #   in seconds.
        setting :offset_commit_interval, 10
        # option offset_commit_threshold [Integer] the number of messages that can be
        #   processed before their offsets are committed. If zero, offset commits are
        #   not triggered by message processing.
        setting :offset_commit_threshold, 0
        # option heartbeat_interval [Integer] the interval between heartbeats; must be less
        #   than the session window.
        setting :heartbeat_interval, 10

        # SSL authentication related settings
        setting :ssl do
          # option ca_cert [String] SSL CA certificate
          setting :ca_cert, nil
          # option client_cert [String] SSL client certificate
          setting :client_cert, nil
          # option client_cert_key [String] SSL client certificate password
          setting :client_cert_key, nil
        end
      end

      # This is configured automatically, don't overwrite it!
      # Each route requires separate thread, so number of threads should be equal to number
      # of routes
      setting :concurrency, -> { ::Karafka::App.routes.count }

      class << self
        # Configurating method
        # @yield Runs a block of code providing a config singleton instance to it
        # @yieldparam [Karafka::Setup::Config] Karafka config instance
        def setup
          configure do |config|
            yield(config)
          end
        end

        # Everything that should be initialized after the setup
        # Components are in karafka/config directory and are all loaded one by one
        # If you want to configure a next component, please add a proper file to config dir
        def setup_components
          Configurators::Base.descendants.each do |klass|
            klass.new(config).setup
          end
        end
      end
    end
  end
end
