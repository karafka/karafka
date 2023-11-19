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
    module Processing
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
      class Scheduler < ::Karafka::Processing::Scheduler
        # Schedules jobs in the LJF order for consumption
        #
        # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs we want to schedule
        #
        def schedule_consumption(jobs_array)
          perf_tracker = PerformanceTracker.instance

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

        private

        # @param perf_tracker [PerformanceTracker]
        # @param job [Karafka::Processing::Jobs::Base] job we will be processing
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
