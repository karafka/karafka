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
      # Nested settings node (for hash based settings) - this will allow us to have nice
      # node fetching like kafka.hosts instead of kafka[:hosts]
      # @example Simple node for kafka hosts
      #   node = Node.new(['127.0.0.1'])
      #   node.hosts #=> ['127.0.0.1']
      class Node < OpenStruct; end

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
      # option zookeeper [Hash] zookeeper configuration options (hosts with ports and chroot)
      # option kafka [Hash] - optional - kafka configuration options (hosts)
      SETTINGS = [
        :logger,
        :max_concurrency,
        :monitor,
        :name,
        :redis,
        :wait_timeout,
        zookeeper: %i( hosts ),
        kafka: %i( hosts )
      ].freeze

      # We assume that we can have up to two levels of settings (root settings + additional node)
      # No more nodes are supported (1 level nestings)
      ROOT_SETTINGS = SETTINGS.flat_map { |set| set.is_a?(Hash) ? set.keys : set }

      ROOT_SETTINGS.each do |attr_name|
        attr_writer attr_name

        # @return A given setting value if defined or a default one if not defined
        # @note It will return a default value only if we defined defaults for fallback
        # @note We fallback all the time without caching the value, because it might provide
        #   lazy loaded functionalities like hosts detection etc
        # @example
        #   logger #=> Karafka::Logger instance
        define_method attr_name do
          value = instance_variable_get(:"@#{attr_name}")
          value ||= Defaults.public_send(attr_name) if Defaults.respond_to?(attr_name)

          # If a value is a simple type - we will just return it, if it was defined as a hash
          # (for example for kafka and zookeeper) - we will return a Node object that will allow
          # us to have a nicer fetching
          value.is_a?(Hash) ? Node.new(value) : value
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
