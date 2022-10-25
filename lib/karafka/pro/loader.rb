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
      # All the pro components that need to be loaded
      COMPONENTS = %w[
        base_consumer
        performance_tracker
        processing/scheduler
        processing/jobs/consume_non_blocking
        processing/jobs_builder
        processing/coordinator
        processing/partitioner

        routing/features/base

        routing/features/virtual_partitions
        routing/features/virtual_partitions/config
        routing/features/virtual_partitions/topic
        routing/features/virtual_partitions/contract

        routing/features/long_running_job
        routing/features/long_running_job/config
        routing/features/long_running_job/topic
        routing/features/long_running_job/contract

        routing/features/pro_inheritance
        routing/features/pro_inheritance/topic
        routing/features/pro_inheritance/contract

        active_job/consumer
        active_job/dispatcher
        active_job/job_options_contract
      ].freeze

      private_constant :COMPONENTS

      class << self
        # Requires all the components without using them anywhere
        def require_all
          COMPONENTS.each { |component| require_relative(component) }
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
