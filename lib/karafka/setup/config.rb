# frozen_string_literal: true

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
      # option client_id [String] kafka client_id - used to provide
      #   default Kafka groups namespaces and identify that app in kafka
      setting :client_id
      # What backend do we want to use to process messages
      setting :backend, :inline
      # option logger [Instance] logger that we want to use
      setting :logger, -> { ::Karafka::Logger.instance }
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      setting :monitor, -> { ::Karafka::Monitor.instance }
      # Mapper used to remap consumer groups ids, so in case users migrate from other tools
      # or they need to maintain their own internal consumer group naming conventions, they
      # can easily do it, replacing the default client_id + consumer name pattern concept
      setting :consumer_mapper, -> { Routing::ConsumerMapper }
      # Mapper used to remap names of topics, so we can have a clean internal topic namings
      # despite using any Kafka provider that uses namespacing, etc
      # It needs to implement two methods:
      #   - #incoming - for remapping from the incoming message to our internal format
      #   - #outgoing - for remapping from internal topic name into outgoing message
      setting :topic_mapper, -> { Routing::TopicMapper }
      # Default parser for parsing and unparsing incoming and outgoing data
      setting :parser, -> { Karafka::Parsers::Json }
      # If batch_fetching is true, we will fetch kafka messages in batches instead of 1 by 1
      # @note Fetching does not equal consuming, see batch_consuming description for details
      setting :batch_fetching, true
      # If batch_consuming is true, we will have access to #params_batch instead of #params.
      # #params_batch will contain params received from Kafka (may be more than 1) so we can
      # process them in batches
      setting :batch_consuming, false
      # Should we operate in a single controller instance across multiple batches of messages,
      # from the same partition or should we build a new instance for each incoming batch.
      # Disabling that can be useful when you want to build a new controller instance for each
      # incoming batch. It's disabled by default, not to create more objects that needed on
      # each batch
      setting :persistent, true
      # option shutdown_timeout [Integer, nil] the number of seconds after which Karafka no
      #   longer wait for the consumers to stop gracefully but instead we force
      #   terminate everything.
      # @note Keep in mind, that if your business logic
      # @note If set to nil, it won't forcefully shutdown the process at all.
      setting :shutdown_timeout, 60

      # option kafka [Hash] - optional - kafka configuration options
      setting :kafka do
        # Array with at least one host
        setting :seed_brokers
        # option session_timeout [Integer] the number of seconds after which, if a client
        #   hasn't contacted the Kafka cluster, it will be kicked out of the group.
        setting :session_timeout, 30
        # Time that a given partition will be paused from fetching messages, when message
        # consumption fails. It allows us to process other partitions, while the error is being
        # resolved and also "slows" things down, so it prevents from "eating" up all messages and
        # consuming them with failed code
        setting :pause_timeout, 10
        # option offset_commit_interval [Integer] the interval between offset commits,
        #   in seconds.
        setting :offset_commit_interval, 10
        # option offset_commit_threshold [Integer] the number of messages that can be
        #   processed before their offsets are committed. If zero, offset commits are
        #   not triggered by message consumption.
        setting :offset_commit_threshold, 0
        # option heartbeat_interval [Integer] the interval between heartbeats; must be less
        #   than the session window.
        setting :heartbeat_interval, 10
        # option max_bytes_per_partition [Integer] the maximum amount of data fetched
        #   from a single partition at a time.
        setting :max_bytes_per_partition, 1_048_576
        #  whether to consume messages starting at the beginning or to just consume new messages
        setting :start_from_beginning, true
        # option min_bytes [Integer] the minimum number of bytes to read before
        #   returning messages from the server; if `max_wait_time` is reached, this
        #   is ignored.
        setting :min_bytes, 1
        # option max_wait_time [Integer, Float] max_wait_time is the maximum number of seconds to
        #   wait before returning data from a single message fetch. By setting this high you also
        #   increase the fetching throughput - and by setting it low you set a bound on latency.
        #   This configuration overrides `min_bytes`, so you'll _always_ get data back within the
        #   time specified. The default value is one second. If you want to have at most five
        #   seconds of latency, set `max_wait_time` to 5. You should make sure
        #   max_wait_time * num brokers + heartbeat_interval is less than session_timeout.
        setting :max_wait_time, 1
        # option automatically_mark_as_consumed [Boolean] should we automatically mark received
        # messages as consumed (processed) after non-error consumption
        setting :automatically_mark_as_consumed, true
        # option reconnect_timeout [Integer] How long should we wait before trying to reconnect to
        # Kafka cluster that went down (in seconds)
        setting :reconnect_timeout, 5
        # option offset_retention_time [Integer] The length of the retention window, known as
        #   offset retention time
        setting :offset_retention_time, nil
        # option connect_timeout [Integer] Sets the number of seconds to wait while connecting to
        # a broker for the first time. When ruby-kafka initializes, it needs to connect to at
        # least one host.
        setting :connect_timeout, 10
        # option socket_timeout [Integer] Sets the number of seconds to wait when reading from or
        # writing to a socket connection to a broker. After this timeout expires the connection
        # will be killed. Note that some Kafka operations are by definition long-running, such as
        # waiting for new messages to arrive in a partition, so don't set this value too low
        setting :socket_timeout, 30

        # SSL authentication related settings
        # option ca_cert [String] SSL CA certificate
        setting :ssl_ca_cert, nil
        # option ssl_ca_cert_file_path [String] SSL CA certificate file path
        setting :ssl_ca_cert_file_path, nil
        # option ssl_client_cert [String] SSL client certificate
        setting :ssl_client_cert, nil
        # option ssl_client_cert_key [String] SSL client certificate password
        setting :ssl_client_cert_key, nil
        # option sasl_gssapi_principal [String] sasl principal
        setting :sasl_gssapi_principal, nil
        # option sasl_gssapi_keytab [String] sasl keytab
        setting :sasl_gssapi_keytab, nil
        # option sasl_plain_authzid [String] The authorization identity to use
        setting :sasl_plain_authzid, ''
        # option sasl_plain_username [String] The username used to authenticate
        setting :sasl_plain_username, nil
        # option sasl_plain_password [String] The password used to authenticate
        setting :sasl_plain_password, nil
      end

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

        # Validate config based on ConfigurationSchema
        # @return [Boolean] true if configuration is valid
        # @raise [Karafka::Errors::InvalidConfiguration] raised when configuration
        #   doesn't match with ConfigurationSchema
        def validate!
          validation_result = Karafka::Schemas::Config.call(config.to_h)

          return true if validation_result.success?

          raise Errors::InvalidConfiguration, validation_result.errors
        end
      end
    end
  end
end
