# frozen_string_literal: true

# This Karafka component is a Pro component.
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
        performance_tracker
        scheduler
        base_consumer_extensions
        processing/jobs/consume_non_blocking
        processing/jobs_builder
        routing/extensions
        active_job/consumer
        active_job/dispatcher
        active_job/job_options_contract
      ].freeze

      private_constant :COMPONENTS

      class << self
        # Loads all the pro components and configures them wherever it is expected
        # @param config [Dry::Configurable::Config] whole app config that we can alter with pro
        #   components
        def setup(config)
          COMPONENTS.each { |component| require_relative(component) }

          config.internal.scheduler = Scheduler.new
          config.internal.jobs_builder = Processing::JobsBuilder.new
          config.internal.active_job.consumer = ActiveJob::Consumer
          config.internal.active_job.dispatcher = ActiveJob::Dispatcher.new
          config.internal.active_job.job_options_contract = ActiveJob::JobOptionsContract.new

          ::Karafka::Routing::Topic.include(Routing::Extensions)
          ::Karafka::BaseConsumer.prepend(BaseConsumerExtensions)

          config.monitor.subscribe(PerformanceTracker.instance)
        end
      end
    end
  end
end
