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
      # option max_concurrency [Integer] how many threads that listen to Kafka can we have
      setting :max_concurrency
      # option name [String] current app name - used to provide default Kafka groups namespaces
      setting :name
      # option wait_timeout [Integer] seconds that we will wait on a single topic for messages
      setting :wait_timeout
      # option logger [Instance] logger that we want to use
      setting :logger, ::Karafka::Logger.instance
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      setting :monitor, ::Karafka::Monitor.instance
      # option redis [Hash] redis options hash (url and optional parameters)
      # Note that redis could be rewriten using nested options, but it is a sidekiq specific
      # stuff and we don't want to touch it
      setting :redis
      # option zookeeper [Hash] zookeeper configuration options (hosts with ports and chroot)
      setting :zookeeper do
        setting :hosts
      end
      # option kafka [Hash] - optional - kafka configuration options (hosts)
      setting :kafka do
        setting :hosts, -> { ::Karafka::Connection::BrokerManager.new.all.map(&:host) }
      end

      class << self
        # Configurating method
        # @yield Runs a block of code providing a config singleton instance to it
        # @yieldparam [Karafka::Setup::Config] Karafka config instance
        def setup
          configure do |config|
            yield(config)
          end

          setup_components
        end

        private

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
