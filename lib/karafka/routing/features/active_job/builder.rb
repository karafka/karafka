# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ActiveJob < Base
        # Routing extensions for ActiveJob
        module Builder
          # This method simplifies routes definition for ActiveJob topics / queues by
          # auto-injecting the consumer class
          #
          # @param name [String, Symbol] name of the topic where ActiveJobs jobs should go
          # @param block [Proc] block that we can use for some extra configuration
          def active_job_topic(name, &block)
            topic(name) do
              consumer App.config.internal.active_job.consumer_class
              active_job true

              # This is handled by our custom ActiveJob consumer
              # Without this, default behaviour would cause messages to skip upon shutdown as the
              # offset would be committed for the last message
              manual_offset_management true

              next unless block

              instance_eval(&block)
            end
          end
        end
      end
    end
  end
end
