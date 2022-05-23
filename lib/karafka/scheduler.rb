# frozen_string_literal: true

module Karafka
  # FIFO scheduler for messages coming from various topics and partitions
  class Scheduler
    # Yields jobs in the fifo order
    #
    # @param jobs_array [Array<Karafka::Processing::Jobs::Base>] jobs we want to schedule
    # @yieldparam [Karafka::Processing::Jobs::Base] job we want to enqueue
    def call(jobs_array, &block)
      jobs_array.each(&block)
    end
  end
end
