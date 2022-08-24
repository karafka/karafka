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
      # What backend do we want to use to process messages
      setting :backend, default: :inline
      # option logger [Instance] logger that we want to use
      setting :logger, default: ::Karafka::Instrumentation::Logger.new
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      setting :monitor, default: ::Karafka::Instrumentation::Monitor.new
      # Mapper used to remap consumer groups ids, so in case users migrate from other tools
      # or they need to maintain their own internal consumer group naming conventions, they
      # can easily do it, replacing the default client_id + consumer name pattern concept
      setting :consumer_mapper, default: Routing::ConsumerMapper.new
      # Mapper used to remap names of topics, so we can have a clean internal topic naming
      # despite using any Kafka provider that uses namespacing, etc
      # It needs to implement two methods:
      #   - #incoming - for remapping from the incoming message to our internal format
      #   - #outgoing - for remapping from internal topic name into outgoing message
      setting :topic_mapper, default: Routing::TopicMapper.new
      # Default serializer for converting whatever we want to send to kafka to json
      setting :serializer, default: Karafka::Serialization::Json::Serializer.new
      # Default deserializer for converting incoming data into ruby objects
      setting :deserializer, default: Karafka::Serialization::Json::Deserializer.new
      # If batch_fetching is true, we will fetch kafka messages in batches instead of 1 by 1
      # @note Fetching does not equal consuming, see batch_consuming description for details
      setting :batch_fetching, default: true
      # If batch_consuming is true, we will have access to #params_batch instead of #params.
      # #params_batch will contain params received from Kafka (may be more than 1) so we can
      # process them in batches
      setting :batch_consuming, default: false
      # option shutdown_timeout [Integer, nil] the number of seconds after which Karafka no
      #   longer wait for the consumers to stop gracefully but instead we force terminate
      #   everything.
      setting :shutdown_timeout, default: 60

      # option kafka [Hash] - optional - kafka configuration options
      setting :kafka do
        # Array with at least one host
        setting :seed_brokers, default: %w[kafka://127.0.0.1:9092]
        # option session_timeout [Integer] the number of seconds after which, if a client
        #   hasn't contacted the Kafka cluster, it will be kicked out of the group.
        setting :session_timeout, default: 30
        # Time that a given partition will be paused from fetching messages, when message
        # consumption fails. It allows us to process other partitions, while the error is being
        # resolved and also "slows" things down, so it prevents from "eating" up all messages and
        # consuming them with failed code. Use `nil` if you want to pause forever and never retry.
        setting :pause_timeout, default: 10
        # option pause_max_timeout [Integer, nil] the maximum number of seconds to pause for,
        #   or `nil` if no maximum should be enforced.
        setting :pause_max_timeout, default: nil
        # option pause_exponential_backoff [Boolean] whether to enable exponential backoff
        setting :pause_exponential_backoff, default: false
        # option offset_commit_interval [Integer] the interval between offset commits,
        #   in seconds.
        setting :offset_commit_interval, default: 10
        # option offset_commit_threshold [Integer] the number of messages that can be
        #   processed before their offsets are committed. If zero, offset commits are
        #   not triggered by message consumption.
        setting :offset_commit_threshold, default: 0
        # option heartbeat_interval [Integer] the interval between heartbeats; must be less
        #   than the session window.
        setting :heartbeat_interval, default: 10
        # option offset_retention_time [Integer] The length of the retention window, known as
        #   offset retention time
        setting :offset_retention_time, default: nil
        # option fetcher_max_queue_size [Integer] max number of items in the fetch queue that
        #   are stored for further processing. Note, that each item in the queue represents a
        #   response from a single broker
        setting :fetcher_max_queue_size, default: 10
        # option assignment_strategy [Object] a strategy determining the assignment of
        #   partitions to the consumers.
        setting :assignment_strategy, default: Karafka::AssignmentStrategies::RoundRobin.new
        # option max_bytes_per_partition [Integer] the maximum amount of data fetched
        #   from a single partition at a time.
        setting :max_bytes_per_partition, default: 1_048_576
        #  whether to consume messages starting at the beginning or to just consume new messages
        setting :start_from_beginning, default: true
        # option resolve_seed_brokers [Boolean] whether to resolve each hostname of the seed
        # brokers
        setting :resolve_seed_brokers, default: false
        # option min_bytes [Integer] the minimum number of bytes to read before
        #   returning messages from the server; if `max_wait_time` is reached, this
        #   is ignored.
        setting :min_bytes, default: 1
        # option max_bytes [Integer] the maximum number of bytes to read before returning messages
        #   from each broker.
        setting :max_bytes, default: 10_485_760
        # option max_wait_time [Integer, Float] max_wait_time is the maximum number of seconds to
        #   wait before returning data from a single message fetch. By setting this high you also
        #   increase the fetching throughput - and by setting it low you set a bound on latency.
        #   This configuration overrides `min_bytes`, so you'll _always_ get data back within the
        #   time specified. The default value is one second. If you want to have at most five
        #   seconds of latency, set `max_wait_time` to 5. You should make sure
        #   max_wait_time * num brokers + heartbeat_interval is less than session_timeout.
        setting :max_wait_time, default: 1
        # option rebalance_timeout [Integer] sets number of seconds a broker will wait for a
        #   consumer during a rebalance before considering it dead.
        setting :rebalance_timeout, default: 10
        # option automatically_mark_as_consumed [Boolean] should we automatically mark received
        # messages as consumed (processed) after non-error consumption
        setting :automatically_mark_as_consumed, default: true
        # option reconnect_timeout [Integer] How long should we wait before trying to reconnect to
        # Kafka cluster that went down (in seconds)
        setting :reconnect_timeout, default: 5
        # option connect_timeout [Integer] Sets the number of seconds to wait while connecting to
        # a broker for the first time. When ruby-kafka initializes, it needs to connect to at
        # least one host.
        setting :connect_timeout, default: 10
        # option socket_timeout [Integer] Sets the number of seconds to wait when reading from or
        # writing to a socket connection to a broker. After this timeout expires the connection
        # will be killed. Note that some Kafka operations are by definition long-running, such as
        # waiting for new messages to arrive in a partition, so don't set this value too low
        setting :socket_timeout, default: 30
        # option partitioner [Object, nil] the partitioner that should be used by the client
        setting :partitioner, default: nil

        # SSL authentication related settings
        # option ca_cert [String, nil] SSL CA certificate
        setting :ssl_ca_cert, default: nil
        # option ssl_ca_cert_file_path [String, nil] SSL CA certificate file path
        setting :ssl_ca_cert_file_path, default: nil
        # option ssl_ca_certs_from_system [Boolean] Use the CA certs from your system's default
        #   certificate store
        setting :ssl_ca_certs_from_system, default: false
        # option ssl_verify_hostname [Boolean] Verify the hostname for client certs
        setting :ssl_verify_hostname, default: true
        # option ssl_client_cert [String, nil] SSL client certificate
        setting :ssl_client_cert, default: nil
        # option ssl_client_cert_key [String, nil] SSL client certificate password
        setting :ssl_client_cert_key, default: nil
        # option sasl_gssapi_principal [String, nil] sasl principal
        setting :sasl_gssapi_principal, default: nil
        # option sasl_gssapi_keytab [String, nil] sasl keytab
        setting :sasl_gssapi_keytab, default: nil
        # option sasl_plain_authzid [String] The authorization identity to use
        setting :sasl_plain_authzid, default: ''
        # option sasl_plain_username [String, nil] The username used to authenticate
        setting :sasl_plain_username, default: nil
        # option sasl_plain_password [String, nil] The password used to authenticate
        setting :sasl_plain_password, default: nil
        # option sasl_scram_username [String, nil] The username used to authenticate
        setting :sasl_scram_username, default: nil
        # option sasl_scram_password [String, nil] The password used to authenticate
        setting :sasl_scram_password, default: nil
        # option sasl_scram_mechanism [String, nil] Scram mechanism, either 'sha256' or 'sha512'
        setting :sasl_scram_mechanism, default: nil
        # option sasl_over_ssl [Boolean] whether to enforce SSL with SASL
        setting :sasl_over_ssl, default: true
        # option ssl_client_cert_chain [String, nil] client cert chain or nil if not used
        setting :ssl_client_cert_chain, default: nil
        # option ssl_client_cert_key_password [String, nil] the password required to read
        #   the ssl_client_cert_key
        setting :ssl_client_cert_key_password, default: nil
        # @param sasl_oauth_token_provider [Object, nil] OAuthBearer Token Provider instance that
        #   implements method token.
        setting :sasl_oauth_token_provider, default: nil
      end

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
        # option fetcher [Karafka::Fetcher] fetcher instance
        setting :fetcher, default: Fetcher.new
        # option configurators [Array<Object>] all configurators that we want to run after
        #   the setup
        setting :configurators, default: [Configurators::WaterDrop.new]
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
