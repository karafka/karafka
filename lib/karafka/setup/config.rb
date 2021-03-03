# frozen_string_literal: true

module Karafka
  # Module containing all Karafka setup related elements like configuration settings,
  # config validations and configurators for external gems integration
  module Setup
    # Configurator for setting up all the framework details that are required to make it work
    # @note If you want to do some configurations after all of this is done, please add to
    #   karafka/config a proper file (needs to inherit from Karafka::Setup::Configurators::Base
    #   and implement setup method) after that everything will happen automatically
    # @note This config object allows to create a 1 level nesting (nodes) only. This should be
    #   enough and will still keep the code simple
    # @see Karafka::Setup::Configurators::Base for more details about configurators api
    class Config
      extend Dry::Configurable

      # Contract for checking the config provided by the user
      CONTRACT = Karafka::Contracts::Config.new.freeze

      private_constant :CONTRACT

      # Available settings
      # option client_id [String] kafka client_id - used to provide
      #   default Kafka groups namespaces and identify that app in kafka
      setting :client_id
      # option logger [Instance] logger that we want to use
      setting :logger, ::Karafka::Instrumentation::Logger.new
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      setting :monitor, ::Karafka::Instrumentation::Monitor.new
      # Mapper used to remap consumer groups ids, so in case users migrate from other tools
      # or they need to maintain their own internal consumer group naming conventions, they
      # can easily do it, replacing the default client_id + consumer name pattern concept
      setting :consumer_mapper, Routing::ConsumerMapper.new
      # Default deserializer for converting incoming data into ruby objects
      setting :deserializer, Karafka::Serialization::Json::Deserializer.new
      # option shutdown_timeout [Integer, nil] the number of seconds after which Karafka no
      #   longer wait for the consumers to stop gracefully but instead we force terminate
      #   everything.
      setting :shutdown_timeout, 60
      # options max_messages [Integer] how many messages do we want to fetch from Kafka in one go
      setting :max_messages, 100_000
      # option [Integer] number of seconds we can wait while fetching data
      setting :max_wait_time, 10_000

      # rdkafka default options
      # @see https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md
      setting :kafka, {}

      setting :processing do
        # option [Integer] number of threads in which we want to do parallel processing
        setting :concurrency, 5

        setting :pause_timeout, 1_000

        setting :pause_max_timeout, 30_000

        setting :pause_with_exponential_backoff, true
      end

      # Namespace for internal settings that should not be modified
      # It's a temporary step to "declassify" several things internally before we move to a
      # non global state
      setting :internal do
        # option routing_builder [Karafka::Routing::Builder] builder instance
        setting :routing_builder, Routing::Builder.new
        # option status [Karafka::Status] app status
        setting :status, Status.new
        # option process [Karafka::Process] process status
        # @note In the future, we need to have a single process representation for all the karafka
        #   instances
        setting :process, Process.new
        # option configurators [Array<Object>] all configurators that we want to run after
        #   the setup
        setting :configurators, [Configurators::WaterDrop.new]
        # option []
        setting :subscription_groups_builder, Routing::SubscriptionGroupsBuilder.new
      end

      class << self
        # Configuring method
        # @yield Runs a block of code providing a config singleton instance to it
        # @yieldparam [Karafka::Setup::Config] Karafka config instance
        def setup
          configure { |config| yield(config) }
        end

        # Everything that should be initialized after the setup
        # Components are in karafka/config directory and are all loaded one by one
        # If you want to configure a next component, please add a proper file to config dir
        def setup_components
          config
            .internal
            .configurators
            .each { |configurator| configurator.call(config) }
        end

        # Validate config based on the config contract
        # @return [Boolean] true if configuration is valid
        # @raise [Karafka::Errors::InvalidConfigurationError] raised when configuration
        #   doesn't match with the config contract
        def validate!
          validation_result = CONTRACT.call(config.to_h)

          return true if validation_result.success?

          raise Errors::InvalidConfigurationError, validation_result.errors.to_h
        end
      end
    end
  end
end
