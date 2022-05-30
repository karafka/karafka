# frozen_string_literal: true

module Karafka
  # FIFO scheduler for messages coming from various topics and partitions
  class Scheduler
    # Schedules jobs in the fifo order
    #
    # @param queue [Karafka::Processing::JobsQueue] queue where we want to put the jobs
    # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs we want to schedule
    def schedule_consumption(queue, jobs_array)
      jobs_array.each do |job|
        queue << job
      end
    end

    # Both revocation and shutdown jobs can also run in fifo by default
    alias schedule_revocation schedule_consumption
    alias schedule_shutdown schedule_consumption
  end
end
