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
      extend ::Karafka::Core::Configurable

      # Available settings

      # Namespace for Pro version related license management. If you use LGPL, no need to worry
      #   about any of this
      setting :license do
        # option token [String, false] - license token issued when you acquire a Pro license
        # Leave false if using the LGPL version and all is going to work just fine :)
        #
        # @note By using the commercial components, you accept the LICENSE-COMM commercial license
        #   terms and conditions
        setting :token, default: false
        # option entity [String] for whom we did issue the license
        setting :entity, default: ''
      end

      # option client_id [String] kafka client_id - used to provide
      #   default Kafka groups namespaces and identify that app in kafka
      setting :client_id, default: 'karafka'
      # option logger [Instance] logger that we want to use
      setting :logger, default: ::Karafka::Instrumentation::Logger.new
      # option monitor [Instance] monitor that we will to use (defaults to Karafka::Monitor)
      setting :monitor, default: ::Karafka::Instrumentation::Monitor.new
      # option [Boolean] should we reload consumers with each incoming batch thus effectively
      # supporting code reload (if someone reloads code) or should we keep the persistence
      setting :consumer_persistence, default: true
      # option [String] should we start with the earliest possible offset or latest
      # This will set the `auto.offset.reset` value unless present in the kafka scope
      setting :initial_offset, default: 'earliest'
      # options max_messages [Integer] how many messages do we want to fetch from Kafka in one go
      setting :max_messages, default: 100
      # option [Integer] number of milliseconds we can wait while fetching data
      setting :max_wait_time, default: 1_000
      # option shutdown_timeout [Integer] the number of milliseconds after which Karafka no
      #   longer waits for the consumers to stop gracefully but instead we force terminate
      #   everything.
      setting :shutdown_timeout, default: 60_000
      # option [Integer] number of threads in which we want to do parallel processing
      setting :concurrency, default: 5
      # option [Integer] how long should we wait upon processing error (milliseconds)
      setting :pause_timeout, default: 1_000
      # option [Integer] what is the max timeout in case of an exponential backoff (milliseconds)
      setting :pause_max_timeout, default: 30_000
      # option [Boolean] should we use exponential backoff
      setting :pause_with_exponential_backoff, default: true
      # option [::WaterDrop::Producer, nil]
      # Unless configured, will be created once Karafka is configured based on user Karafka setup
      setting :producer, default: nil
      # option [Boolean] when set to true, Karafka will ensure that the routing topic naming
      # convention is strict
      # Disabling this may be needed in scenarios where we do not have control over topics names
      # and/or we work with existing systems where we cannot change topics names.
      setting :strict_topics_namespacing, default: true
      # option [String] default consumer group name for implicit routing
      setting :group_id, default: 'app'
      # option [Boolean] when set to true, it will validate as part of the routing validation, that
      # all topics and DLQ topics (even not active) have the declarative topics definitions.
      # Really useful when you want to ensure that all topics in routing are managed via
      # declaratives.
      setting :strict_declarative_topics, default: false

      setting :oauth do
        # option [false, #call] Listener for using oauth bearer. This listener will be able to
        #   get the client name to decide whether to use a single multi-client token refreshing
        #   or have separate tokens per instance.
        setting :token_provider_listener, default: false
      end

      # rdkafka default options
      # @see https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md
      setting :kafka, default: {}

      # Public configuration for swarm operations
      setting :swarm do
        # option [Integer] how many processes do we want to run in a swarm mode
        # Keep in mind this is only applicable when running in a swarm mode
        setting :nodes, default: 3
        # This is set automatically when we fork. Used to hold reference that may be needed
        # for static group membership, supervision and more. If set to `false`, it means this
        # process is not a fork
        setting :node, default: false
      end

      # Admin specific settings.
      #
      # Since admin operations are often specific, they may require specific librdkafka settings
      # or other settings that are unique to admin.
      setting :admin do
        # Specific kafka settings that are tuned to operate within the Admin.
        #
        # Please do not change them unless you know what you are doing as their misconfiguration
        # may cause Admin API to misbehave
        # option [Hash] extra changes to the default root kafka settings
        setting :kafka, default: {
          # We want to know when there is no more data not to end up with an endless loop
          'enable.partition.eof': true,
          # Do not publish statistics from admin as they are not relevant
          'statistics.interval.ms': 0,
          # Fetch at most 5 MBs when using admin
          'fetch.message.max.bytes': 5 * 1_048_576,
          # Do not commit offset automatically, this prevents offset tracking for operations
          # involving a consumer instance
          'enable.auto.commit': false,
          # Make sure that topic metadata lookups do not create topics accidentally
          'allow.auto.create.topics': false,
          # Do not store offsets automatically in admin in any way
          'enable.auto.offset.store': false
        }

        # option [String] default name for the admin consumer group.
        setting :group_id, default: 'karafka_admin'

        # option max_wait_time [Integer] We wait only for this amount of time before raising error
        # as we intercept this error and retry after checking that the operation was finished or
        # failed using external factor.
        setting :max_wait_time, default: 1_000

        # How many times should be try. 1 000 ms x 60 => 60 seconds wait in total and then we give
        # up on pending operations
        setting :max_attempts, default: 60
      end

      # Namespace for internal settings that should not be modified directly
      setting :internal do
        # option status [Karafka::Status] app status
        setting :status, default: Status.new
        # option process [Karafka::Process] process status
        # @note In the future, we need to have a single process representation for all the karafka
        #   instances
        setting :process, default: Process.new
        # Interval of "ticking". This is used to define the maximum time between consecutive
        # polling of the main rdkafka queue. It should match also the `statistics.interval.ms`
        # smallest value defined in any of the per-kafka settings, so metrics are published with
        # the desired frequency. It is set to 5 seconds because `statistics.interval.ms` is also
        # set to five seconds.
        #
        # It is NOT allowed to set it to a value less than 1 seconds because it could cause polling
        # not to have enough time to run. This (not directly) defines also a single poll
        # max timeout as to allow for frequent enough events polling
        setting :tick_interval, default: 5_000
        # How long should we sleep between checks on shutting down consumers
        setting :supervision_sleep, default: 0.1
        # What system exit code should we use when we terminated forcefully
        setting :forceful_exit_code, default: 2

        setting :swarm do
          # Manager for swarm nodes control
          setting :manager, default: Swarm::Manager.new
          # Exit code we exit an orphaned child with to indicate something went wrong
          setting :orphaned_exit_code, default: 3
          # syscall number for https://man7.org/linux/man-pages/man2/pidfd_open.2.html
          setting :pidfd_open_syscall, default: 434
          # syscall number for https://man7.org/linux/man-pages/man2/pidfd_send_signal.2.html
          setting :pidfd_signal_syscall, default: 424
          # How often (in ms) should we control our nodes
          # This is maximum time after which we will check. This can happen more often in case of
          # system events.
          setting :supervision_interval, default: 30_000
          # How often should each node report its status
          setting :liveness_interval, default: 10_000
          # Listener used to report nodes state to the supervisor
          setting :liveness_listener, default: Swarm::LivenessListener.new
          # How long should we wait for any info from the node before we consider it hanging at
          # stop it
          setting :node_report_timeout, default: 60_000
          # How long should we wait before restarting a node. This can prevent us from having a
          # case where for some external reason our spawned process would die immediately and we
          # would immediately try to start it back in an endless loop
          setting :node_restart_timeout, default: 5_000
        end

        # Namespace for CLI related settings
        setting :cli do
          # option contract [Object] cli setup validation contract (in the context of options and
          # topics)
          setting :contract, default: Contracts::ServerCliOptions.new
        end

        setting :routing do
          # option builder [Karafka::Routing::Builder] builder instance
          setting :builder, default: Routing::Builder.new
          # option subscription_groups_builder [Routing::SubscriptionGroupsBuilder] subscription
          #   group builder
          setting :subscription_groups_builder, default: Routing::SubscriptionGroupsBuilder.new
          # Internally assigned list of limits on routings active for the current process
          # This can be altered by the CLI command
          setting :activity_manager, default: Routing::ActivityManager.new
        end

        # Namespace for internal connection related settings
        setting :connection do
          # Manages starting up and stopping Kafka connections
          setting :manager, default: Connection::Manager.new
          # Controls frequency of connections management checks
          setting :conductor, default: Connection::Conductor.new
          # How long should we wait before a critical listener recovery
          # Too short may cause endless rebalance loops
          setting :reset_backoff, default: 60_000

          # Settings that are altered by our client proxy layer
          setting :proxy do
            # commit offsets request
            setting :commit do
              # How many times should we try to run this call before raising an error
              setting :max_attempts, default: 3
              # How long should we wait before next attempt in case of a failure
              setting :wait_time, default: 1_000
            end

            # Committed offsets for given CG query
            setting :committed do
              # timeout for this request. For busy or remote clusters, this should be high enough
              setting :timeout, default: 5_000
              # How many times should we try to run this call before raising an error
              setting :max_attempts, default: 3
              # How long should we wait before next attempt in case of a failure
              setting :wait_time, default: 1_000
            end

            # Watermark offsets request settings
            setting :query_watermark_offsets do
              # timeout for this request. For busy or remote clusters, this should be high enough
              setting :timeout, default: 5_000
              # How many times should we try to run this call before raising an error
              setting :max_attempts, default: 3
              # How long should we wait before next attempt in case of a failure
              setting :wait_time, default: 1_000
            end

            # Offsets for times request settings
            setting :offsets_for_times do
              # timeout for this request. For busy or remote clusters, this should be high enough
              setting :timeout, default: 5_000
              # How many times should we try to run this call before raising an error
              setting :max_attempts, default: 3
              # How long should we wait before next attempt in case of a failure
              setting :wait_time, default: 1_000
            end

            # Settings for lag request
            setting :lag do
              # timeout for this request. For busy or remote clusters, this should be high enough
              setting :timeout, default: 10_000
              # How many times should we try to run this call before raising an error
              setting :max_attempts, default: 3
              # How long should we wait before next attempt in case of a failure
              setting :wait_time, default: 1_000
            end

            # Settings for metadata request
            setting :metadata do
              # timeout for this request. For busy or remote clusters, this should be high enough
              setting :timeout, default: 10_000
              # How many times should we try to run this call before raising an error
              setting :max_attempts, default: 3
              # How long should we wait before next attempt in case of a failure
              setting :wait_time, default: 1_000
            end
          end
        end

        setting :processing do
          setting :jobs_queue_class, default: Processing::JobsQueue
          # option scheduler [Object] scheduler we will be using
          setting :scheduler_class, default: Processing::Schedulers::Default
          # option jobs_builder [Object] jobs builder we want to use
          setting :jobs_builder, default: Processing::JobsBuilder.new
          # option coordinator [Class] work coordinator we want to user for processing coordination
          setting :coordinator_class, default: Processing::Coordinator
          # option partitioner_class [Class] partitioner we use against a batch of data
          setting :partitioner_class, default: Processing::Partitioner
          # option strategy_selector [Object] processing strategy selector to be used
          setting :strategy_selector, default: Processing::StrategySelector.new
          # option expansions_selector [Object] processing expansions selector to be used
          setting :expansions_selector, default: Processing::ExpansionsSelector.new
          # option [Class] executor class
          setting :executor_class, default: Processing::Executor
          # option worker_job_call_wrapper [Proc, false] callable object that will be used to wrap
          #   the worker execution of a job or false if no wrapper needed
          setting :worker_job_call_wrapper, default: false
        end

        # Things related to operating on messages
        setting :messages do
          # Parser is used to convert raw payload prior to deserialization
          setting :parser, default: Messages::Parser.new
        end

        # Karafka components for ActiveJob
        setting :active_job do
          # option dispatcher [Karafka::ActiveJob::Dispatcher] default dispatcher for ActiveJob
          setting :dispatcher, default: ActiveJob::Dispatcher.new
          # option job_options_contract [Karafka::Contracts::JobOptionsContract] contract for
          #   ensuring, that extra job options defined are valid
          setting :job_options_contract, default: ActiveJob::JobOptionsContract.new
          # option consumer [Class] consumer class that should be used to consume ActiveJob data
          setting :consumer_class, default: ActiveJob::Consumer
        end
      end

      # This will load all the defaults that can be later overwritten.
      # Thanks to that we have an initial state out of the box.
      configure

      class << self
        # Configuring method
        # @param block [Proc] block we want to execute with the config instance
        def setup(&block)
          # Will prepare and verify license if present
          Licenser.prepare_and_verify(config.license)

          # Pre-setup configure all routing features that would need this
          Routing::Features::Base.pre_setup_all(config)

          # Will configure all the pro components
          # This needs to happen before end user configuration as the end user may overwrite some
          # of the pro defaults with custom components
          Pro::Loader.pre_setup_all(config) if Karafka.pro?

          configure(&block)

          Contracts::Config.new.validate!(config.to_h)

          configure_components

          # Refreshes the references that are cached that might have been changed by the config
          ::Karafka.refresh!

          # Post-setup configure all routing features that would need this
          Routing::Features::Base.post_setup_all(config)

          # Runs things that need to be executed after config is defined and all the components
          # are also configured
          Pro::Loader.post_setup_all(config) if Karafka.pro?

          # Subscribe the assignments tracker so we can always query all current assignments
          config.monitor.subscribe(Instrumentation::AssignmentsTracker.instance)

          Karafka::App.initialized!
        end

        private

        # Sets up all the components that are based on the user configuration
        # @note At the moment it is only WaterDrop
        def configure_components
          oauth_listener = config.oauth.token_provider_listener
          # We need to subscribe the oauth listener here because we want it to be ready before
          # any consumer/admin runs
          Karafka::App.monitor.subscribe(oauth_listener) if oauth_listener

          config.producer ||= ::WaterDrop::Producer.new do |producer_config|
            # In some cases WaterDrop updates the config and we don't want our consumer config to
            # be polluted by those updates, that's why we copy
            producer_config.kafka = AttributesMap.producer(config.kafka.dup)
            # We also propagate same listener to the default producer to make sure, that the
            # listener for oauth is also automatically used by the producer. That way we don't
            # have to configure it manually for the default producer
            producer_config.oauth.token_provider_listener = oauth_listener
            producer_config.logger = config.logger
          end
        end
      end
    end
  end
end
