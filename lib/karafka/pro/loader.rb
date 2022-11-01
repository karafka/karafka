# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.


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
        def setup(config)
          require_all

          reconfigure(config)

          load_topic_features
        end

        private

        # Sets proper config options to use pro components
        # @param config [WaterDrop::Configurable::Node] root config node
        def reconfigure(config)
          icfg = config.internal

          icfg.processing.coordinator_class = Processing::Coordinator
          icfg.processing.partitioner_class = Processing::Partitioner
          icfg.processing.scheduler = Processing::Scheduler.new
          icfg.processing.jobs_builder = Processing::JobsBuilder.new
          icfg.processing.strategy_selector = Processing::StrategySelector.new

          icfg.active_job.consumer_class = ActiveJob::Consumer
          icfg.active_job.dispatcher = ActiveJob::Dispatcher.new
          icfg.active_job.job_options_contract = ActiveJob::JobOptionsContract.new

          config.monitor.subscribe(PerformanceTracker.instance)
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
