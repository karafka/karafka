module Karafka
  # Module containing all Karafka setup related elements like configuration settings,
  # config validations and configurators for external gems integration
  module Setup
    # Configurator for setting up all the framework details that are required to make it work
    # @note If you want to do some configurations after all of this is done, please add to
    #   karafka/config a proper file (needs to inherit from Karafka::Setup::Config::Base
    #   and implement setup method) after that everything will happen automatically
    # @see Karafka::Setup::Config::Base for more details about configurators api
    class Config
      class << self
        attr_accessor :config
      end

      # Available settings
      # option logger [Instance] logger that we want to use (defaults to Karafka::Logger)
      # option max_concurrency [Integer] how many threads that listen to Kafka can we have
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      # option name [String] current app name - used to provide default Kafka groups namespaces
      # option redis [Hash] redis options hash (url and optional parameters)
      # option wait_timeout [Integer] seconds that we will wait on a single topic for messages
      # option zookeeper_hosts [Array] zookeeper hosts with ports where zookeeper servers are run
      # option kafka_hosts [Array] - optional - kafka hosts with ports (autodiscovered if missing)
      SETTINGS = [
        :logger,
        :max_concurrency,
        :monitor,
        :name,
        :redis,
        :wait_timeout,
        :zookeeper_hosts,
        :kafka_hosts
      ].freeze

      SETTINGS.each do |attr_name|
        attr_writer attr_name

        # @return A given setting value if defined or a default one if not defined
        # @note It will return a default value only if we defined defaults for fallback
        # @note We fallback all the time without caching the value, because it might provide
        #   lazy loaded functionalities like hosts detection etc
        # @example
        #   logger #=> Karafka::Logger instance
        define_method attr_name do
          value = instance_variable_get(:"@#{attr_name}")

          return value if value
          return Defaults.public_send(attr_name) if Defaults.respond_to?(attr_name)

          nil
        end
      end

      class << self
        # Configurating method
        # @yield Runs a block of code providing a config singleton instance to it
        # @yieldparam [Karafka::Setup::Config] Karafka config instance
        def setup
          self.config ||= new

          yield(config)

          # This is a class method and we don't want to make setup_components
          # public but we still want to invoke it here
          config.send :setup_components
          config.freeze
        end
      end

      private

      # Everything that should be initialized after the setup
      # Components are in karafka/config directory and are all loaded one by one
      # If you want to configure a next component, please add a proper file to config dir
      def setup_components
        # We configure internals first because other configurators rely on them
        Configurators::Internals.new(self).setup

        Configurators::Base.descendants.each do |klass|
          klass.new(self).setup
        end
      end
    end
  end
end
