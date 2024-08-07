# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace for Karafka OSS schedulers
    module Schedulers
      # FIFO scheduler for messages coming from various topics and partitions
      class Default
        # @param queue [Karafka::Processing::JobsQueue] queue where we want to put the jobs
        def initialize(queue)
          @queue = queue
        end

        # Schedules jobs in the fifo order
        #
        # @param jobs_array [Array<Karafka::Processing::Jobs::Consume>] jobs we want to schedule
        def on_schedule_consumption(jobs_array)
          jobs_array.each do |job|
            @queue << job
          end
        end

        # Revocation, shutdown and idle jobs can also run in fifo by default
        alias on_schedule_revocation on_schedule_consumption
        alias on_schedule_shutdown on_schedule_consumption
        alias on_schedule_idle on_schedule_consumption
        alias on_schedule_eofed on_schedule_consumption

        # This scheduler does not have anything to manage as it is a pass through and has no state
        def on_manage
          nil
        end

        # This scheduler does not need to be cleared because it is stateless
        #
        # @param _group_id [String] Subscription group id
        def on_clear(_group_id)
          nil
        end
      end
    end
  end
end
