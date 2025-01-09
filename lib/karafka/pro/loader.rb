# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Loader requires and loads all the pro components only when they are needed
    class Loader
      # There seems to be a conflict in between using two Zeitwerk instances and it makes lookups
      # for nested namespaces instead of creating them.
      # We require those not to deal with this and then all works as expected
      FORCE_LOADED = %w[
        active_job/dispatcher
        processing/jobs/consume_non_blocking
        processing/strategies/base
        routing/features/base
        encryption
        encryption/cipher
        encryption/setup/config
        encryption/contracts/config
        encryption/messages/parser
      ].freeze

      # Zeitwerk pro loader
      # We need to have one per process, that's why it's set as a constant
      PRO_LOADER = Zeitwerk::Loader.new

      private_constant :PRO_LOADER

      class << self
        # Requires all the components without using them anywhere
        def require_all
          FORCE_LOADED.each { |file| require_relative(file) }

          PRO_LOADER.push_dir(Karafka.core_root.join('pro'), namespace: Karafka::Pro)
          PRO_LOADER.setup
          PRO_LOADER.eager_load
        end

        # Loads all the pro components and configures them wherever it is expected
        # @param config [Karafka::Core::Configurable::Node] app config that we can alter with pro
        #   components
        def pre_setup_all(config)
          features.each { |feature| feature.pre_setup(config) }

          reconfigure(config)
          expand

          load_topic_features
        end

        # Runs post setup features configuration operations
        #
        # @param config [Karafka::Core::Configurable::Node]
        def post_setup_all(config)
          features.each { |feature| feature.post_setup(config) }

          # We initialize it here so we don't initialize it during multi-threading work
          Processing::SubscriptionGroupsCoordinator.instance
        end

        private

        # @return [Array<Module>] extra non-routing related pro features and routing components
        #   that need to have some special configuration stuff injected into config, etc
        def features
          [
            Cleaner,
            Encryption,
            RecurringTasks,
            ScheduledMessages
          ]
        end

        # Sets proper config options to use pro components
        # @param config [::Karafka::Core::Configurable::Node] root config node
        def reconfigure(config)
          icfg = config.internal

          icfg.cli.contract = Contracts::ServerCliOptions.new

          # Use manager that supports multiplexing
          icfg.connection.manager = Connection::Manager.new

          icfg.processing.coordinator_class = Processing::Coordinator
          icfg.processing.partitioner_class = Processing::Partitioner
          icfg.processing.scheduler_class = Processing::Schedulers::Default
          icfg.processing.jobs_queue_class = Processing::JobsQueue
          icfg.processing.executor_class = Processing::Executor
          icfg.processing.jobs_builder = Processing::JobsBuilder.new
          icfg.processing.strategy_selector = Processing::StrategySelector.new
          icfg.processing.expansions_selector = Processing::ExpansionsSelector.new

          icfg.active_job.consumer_class = ActiveJob::Consumer
          icfg.active_job.dispatcher = ActiveJob::Dispatcher.new
          icfg.active_job.job_options_contract = ActiveJob::JobOptionsContract.new

          config.monitor.subscribe(Instrumentation::PerformanceTracker.instance)
        end

        # Adds extra modules to certain classes
        # This expands their functionalities with things that are needed when operating in Pro
        # It is used only when given class is part of the end user API and cannot be swapped by
        # a pluggable component
        def expand
          Karafka::BaseConsumer.include Pro::BaseConsumer
        end

        # Loads the Pro features of Karafka
        # @note Object space lookup is not the fastest but we do it once during boot, so it's ok
        def load_topic_features
          ::Karafka::Pro::Routing::Features::Base.load_all
        end
      end
    end
  end
end
