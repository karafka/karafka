# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Namespace for Pro schedulers
      module Schedulers
        # Optimizes scheduler that takes into consideration of execution time needed to process
        # messages from given topics partitions. It uses the non-preemptive LJF algorithm
        #
        # This scheduler is designed to optimize execution times on jobs that perform IO operations
        # as when taking IO into consideration, the can achieve optimized parallel processing.
        #
        # This scheduler can also work with virtual partitions.
        #
        # Aside from consumption jobs, other jobs do not run often, thus we can leave them with
        # default FIFO scheduler from the default Karafka scheduler
        #
        # @note This is a stateless scheduler, thus we can override the `#on_` API.
        class Default < Base
          # Schedules jobs in the LJF order for consumption
          #
          # @param jobs_array
          #   [Array<Karafka::Processing::Jobs::Consume, Processing::Jobs::ConsumeNonBlocking>]
          #   jobs for scheduling
          def on_schedule_consumption(jobs_array)
            perf_tracker = Instrumentation::PerformanceTracker.instance

            ordered = []

            jobs_array.each do |job|
              ordered << [
                job,
                processing_cost(perf_tracker, job)
              ]
            end

            ordered.sort_by!(&:last)
            ordered.reverse!
            ordered.map!(&:first)

            ordered.each do |job|
              @queue << job
            end
          end

          # Schedules any jobs provided in a fifo order
          # @param jobs_array [Array<Karafka::Processing::Jobs::Base>]
          def schedule_fifo(jobs_array)
            jobs_array.each do |job|
              @queue << job
            end
          end

          # By default all non-consumption work is scheduled in a fifo order
          alias on_schedule_revocation schedule_fifo
          alias on_schedule_shutdown schedule_fifo
          alias on_schedule_idle schedule_fifo
          alias on_schedule_periodic schedule_fifo
          alias on_schedule_eofed schedule_fifo

          # This scheduler does not have anything to manage as it is a pass through and has no
          # state
          def on_manage
            nil
          end

          # This scheduler does not need to be cleared because it is stateless
          #
          # @param _group_id [String] Subscription group id
          def on_clear(_group_id)
            nil
          end

          private

          # @param perf_tracker [PerformanceTracker]
          # @param job [Karafka::Processing::Jobs::Consume] job we will be processing
          # @return [Numeric] estimated cost of processing this job
          def processing_cost(perf_tracker, job)
            if job.is_a?(::Karafka::Processing::Jobs::Consume)
              messages = job.messages
              message = messages.first

              perf_tracker.processing_time_p95(message.topic, message.partition) * messages.size
            else
              # LJF will set first the most expensive, but we want to run the zero cost jobs
              # related to the lifecycle always first. That is why we "emulate" that they
              # the longest possible jobs that anyone can run
              Float::INFINITY
            end
          end
        end
      end
    end
  end
end
