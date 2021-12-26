# frozen_string_literal: true

module ActiveJob
  # Routing extensions for ActiveJob
  module RoutingExtensions
    # This method simplifies routes definition for ActiveJob topics / queues by auto-injecting the
    # consumer class
    # @param name [String, Symbol] name of the topic where ActiveJobs jobs should go
    def active_job_topic(name)
      topic(name) do
        consumer ActiveJob::Consumer
      end
    end
  end
end
