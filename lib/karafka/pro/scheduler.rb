# frozen_string_literal: true

module Karafka
  module Pro
    # This Karafka component is a Pro component.
    # All of the commercial components are present in the lib/karafka/pro directory of this
    # repository and their usage requires commercial license agreement.
    #
    # Karafka has also commercial-friendly license, commercial support and commercial components.
    #
    # By sending a pull request to the pro components, you are agreeing to transfer the copyright
    # of your code to Maciej Mensfeld.

    # Optimizes scheduler that takes into consideration of execution time needed to process
    # messages from given topics partitions. It uses the non-preemptive LJF algorithm
    #
    # This scheduler is designed to optimize execution times on jobs that perform IO operations as
    # when taking IO into consideration, the can achieve optimized parallel processing.
    #
    # This scheduler can also work with virtual partitions.
    #
    # Aside from consumption jobs, other jobs do not run often, thus we can leave them with
    # default FIFO scheduler from the default Karafka scheduler
    class Scheduler < ::Karafka::Scheduler
      # Schedules jobs in the LJF order for consumption
      #
      # @param queue [Karafka::Processing::JobsQueue] queue where we want to put the jobs
      # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs we want to schedule
      #
      def schedule_consumption(queue, jobs_array)
        pt = PerformanceTracker.instance

        ordered = []

        jobs_array.each do |job|
          messages = job.messages
          message = messages.first

          cost = pt.processing_time_p95(message.topic, message.partition) * messages.size

          ordered << [job, cost]
        end

        ordered.sort_by!(&:last)
        ordered.reverse!
        ordered.map!(&:first)

        ordered.each do |job|
          queue << job
        end
      end
    end
  end
end
