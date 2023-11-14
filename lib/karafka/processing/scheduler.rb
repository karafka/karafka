# frozen_string_literal: true

module Karafka
  module Processing
    # FIFO scheduler for messages coming from various topics and partitions
    class Scheduler
      # @param queue [Karafka::Processing::JobsQueue] queue where we want to put the jobs
      def initialize(queue)
        @queue = queue
      end

      # Schedules jobs in the fifo order
      #
      # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs we want to schedule
      def schedule_consumption(jobs_array)
        p 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
        jobs_array.each do |job|
          @queue << job
        end
      end

      # Both revocation and shutdown jobs can also run in fifo by default
      alias schedule_revocation schedule_consumption
      alias schedule_shutdown schedule_consumption

      # This scheduler does not have anything to manage as it is a pass through and has no state
      def manage
        nil
      end

      # This scheduler does not need to be cleared because it is stateless
      #
      # @param _group_id [String] Subscription group id
      def clear(_group_id)
        nil
      end
    end
  end
end
