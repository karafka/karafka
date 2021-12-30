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

      # Defaults for kafka settings, that will be overwritten only if not present already
      KAFKA_DEFAULTS = {
        'client.id' => 'karafka'
      }.freeze

      private_constant :CONTRACT, :KAFKA_DEFAULTS

      # Available settings
      # option client_id [String] kafka client_id - used to provide
      #   default Kafka groups namespaces and identify that app in kafka
      setting :client_id, default: 'karafka'
      # option logger [Instance] logger that we want to use
      setting :logger, default: ::Karafka::Instrumentation::Logger.new
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      setting :monitor, default: ::Karafka::Instrumentation::Monitor.new
      # Mapper used to remap consumer groups ids, so in case users migrate from other tools
      # or they need to maintain their own internal consumer group naming conventions, they
      # can easily do it, replacing the default client_id + consumer name pattern concept
      setting :consumer_mapper, default: Routing::ConsumerMapper.new
      # Default deserializer for converting incoming data into ruby objects
      setting :deserializer, default: Karafka::Serialization::Json::Deserializer.new
      # option [Boolean] should we leave offset management to the user
      setting :manual_offset_management, default: false
      # options max_messages [Integer] how many messages do we want to fetch from Kafka in one go
      setting :max_messages, default: 100_000
      # option [Integer] number of milliseconds we can wait while fetching data
      setting :max_wait_time, default: 10_000
      # option shutdown_timeout [Integer] the number of milliseconds after which Karafka no
      #   longer waits for the consumers to stop gracefully but instead we force terminate
      #   everything.
      setting :shutdown_timeout, default: 60_000
      # option [Integer] number of threads in which we want to do parallel processing
      setting :concurrency, default: 5
      # option [Integer] how long should we wait upon processing error
      setting :pause_timeout, default: 1_000
      # option [Integer] what is the max timeout in case of an exponential backoff
      setting :pause_max_timeout, default: 30_000
      # option [Boolean] should we use exponential backoff
      setting :pause_with_exponential_backoff, default: true
      # option [::WaterDrop::Producer, nil]
      # Unless configured, will be created once Karafka is configured based on user Karafka setup
      setting :producer, default: nil

      # rdkafka default options
      # @see https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md
      setting :kafka, default: {}

      # Namespace for internal settings that should not be modified
      # It's a temporary step to "declassify" several things internally before we move to a
      # non global state
      setting :internal do
        # option routing_builder [Karafka::Routing::Builder] builder instance
        setting :routing_builder, default: Routing::Builder.new
        # option status [Karafka::Status] app status
        setting :status, default: Status.new
        # option process [Karafka::Process] process status
        # @note In the future, we need to have a single process representation for all the karafka
        #   instances
        setting :process, default: Process.new
        # option subscription_groups_builder [Routing::SubscriptionGroupsBuilder] subscription
        #   group builder
        setting :subscription_groups_builder, default: Routing::SubscriptionGroupsBuilder.new
      end

      class << self
        # Configuring method
        # @param block [Proc] block we want to execute with the config instance
        def setup(&block)
          configure(&block)
          merge_kafka_defaults!(config)
          validate!
          configure_components
        end

        private

        # Propagates the kafka setting defaults unless they are already present
        # This makes it easier to set some values that users usually don't change but still allows
        # them to overwrite the whole hash if they want to
        # @param config [Dry::Configurable::Config] dry config of this producer
        def merge_kafka_defaults!(config)
          KAFKA_DEFAULTS.each do |key, value|
            next if config.kafka.key?(key)

            config.kafka[key] = value
          end
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

        # Sets up all the components that are based on the user configuration
        # @note At the moment it is only WaterDrop
        def configure_components
          config.producer ||= ::WaterDrop::Producer.new do |producer_config|
            # In some cases WaterDrop updates the config and we don't want our consumer config to
            # be polluted by those updates, that's why we copy
            producer_config.kafka = config.kafka.dup
            producer_config.logger = config.logger
          end
        end
      end
    end
  end
end
