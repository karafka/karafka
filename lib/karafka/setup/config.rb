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
      # How should we process messages. For now we support inline mode (asap in the process) or
      # sidekiq mode (schedule to sidekiq)
      setting :processing_adapter, :inline
      # option logger [Instance] logger that we want to use
      setting :logger, -> { ::Karafka::Logger.instance }
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      setting :monitor, -> { ::Karafka::Monitor.instance }
      # option redis [Hash] redis options hash (url and optional parameters)
      # Note that redis could be rewriten using nested options, but it is a sidekiq specific
      # stuff and we don't want to touch it
      setting :redis
      # Mapper used to remap names of topics, so we can have a clean internal topic namings
      # despite using any Kafka provider that uses namespacing, etc
      # It needs to implement two methods:
      #   - #incoming - for remapping from the incoming message to our internal format
      #   - #outgoing - for remapping from internal topic name into outgoing message
      setting :topic_mapper, -> { Routing::Mapper }
      # If batch_consuming is true, we will consume kafka messages in batches instead of 1 by 1
      # @note Consuming does not equal processing, see batch_processing description for details
      setting :batch_consuming, true
      # If batch_processing is true, we will have access to #params_batch instead of #params.
      # #params_batch will contain params received from Kafka (may be more than 1) so we can
      # process them in batches
      setting :batch_processing, false
      # Connection pool options are used for producer (Waterdrop)
      # They are configured automatically based on Sidekiq concurrency and number of consumers
      # The bigger one is selected as we need to be able to send messages from both places
      setting :connection_pool do
        # Connection pool size for producers. Note that we take a bigger number because there
        # are cases when we might have more sidekiq threads than Karafka consumers (small app)
        # or the opposite for bigger systems
        setting :size, lambda {
          [
            ::Karafka::App.consumer_groups.active.count,
            Sidekiq.options[:concurrency]
          ].max
        }
        # How long should we wait for a working resource from the pool before rising timeout
        # With a proper connection pool size, this should never happen
        setting :timeout, 5
      end

      # option kafka [Hash] - optional - kafka configuration options
      setting :kafka do
        # Array with at least one host
        setting :seed_brokers
        # option session_timeout [Integer] the number of seconds after which, if a client
        #   hasn't contacted the Kafka cluster, it will be kicked out of the group.
        setting :session_timeout, 30
        # Time that a given partition will be paused from processing messages, when message
        # processing fails. It allows us to process other partitions, while the error is being
        # resolved and also "slows" things down, so it prevents from "eating" up all messages and
        # processing them with failed code
        setting :pause_timeout, 10
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
        # option max_bytes_per_partition [Integer] the maximum amount of data fetched
        #   from a single partition at a time.
        setting :max_bytes_per_partition, 1_048_576
        #  whether to consume messages starting at the beginning or to just consume new messages
        setting :start_from_beginning, true
        # option min_bytes [Integer] the minimum number of bytes to read before
        #   returning messages from the server; if `max_wait_time` is reached, this
        #   is ignored.
        setting :min_bytes, 1
        # option max_wait_time [Integer, Float] the maximum duration of time to wait before
        #   returning messages from the server, in seconds.
        setting :max_wait_time, 5
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
        setting :socket_timeout, 10
        # SSL authentication related settings
        # option ca_cert [String] SSL CA certificate
        setting :ssl_ca_cert, nil
        # option ssl_ca_cert_file_path [String] SSL CA certificate file path
        setting :ssl_ca_cert_file_path, nil
        # option client_cert [String] SSL client certificate
        setting :ssl_client_cert, nil
        # option client_cert_key [String] SSL client certificate password
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

      # This is configured automatically, don't overwrite it!
      # Each consumer group requires separate thread, so number of threads should be equal to
      # number of consumer groups
      setting :concurrency, -> { ::Karafka::App.consumer_groups.count }

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
