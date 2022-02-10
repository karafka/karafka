# frozen_string_literal: true

module Karafka
  # ActiveJob related Karafka stuff
  module ActiveJob
    # Routing extensions for ActiveJob
    module RoutingExtensions
      # This method simplifies routes definition for ActiveJob topics / queues by auto-injecting
      # the consumer class
      # @param name [String, Symbol] name of the topic where ActiveJobs jobs should go
      def active_job_topic(name)
        topic(name) do
          consumer App.config.internal.active_job.consumer
        end
      end
    end
  end
end
