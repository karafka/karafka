# frozen_string_literal: true

module Karafka
  module Processing
    # This is the key work component for Karafka jobs distribution
    # This queue makes sure, that we can process in parallel only a single job with data from a
    # single partition of a single topic, while allowing processing of other jobs from different
    # partitions and topics.
    #
    # We work with the assumption, that partitions data is evenly distributed.
    class JobsQueue
      # How many things we can have in the buffer per executor before triggering `#wait`
      BUFFERS_LIMIT = 5

      private_constant :BUFFERS_LIMIT

      # @return [Karafka::Processing::JobsQueue]
      def initialize
        @queue = Queue.new
        @in_processing = {}
        @mutex = Mutex.new
      end

      # Adds the job to the internal buffers and if doable, schedules it for execution
      # @param job [Karafka::Processing::Job] job that we want to run
      def <<(job)
        return if @queue.closed?

        @in_processing[job.executor.id] = true
        @queue << job
      end

      def fetch
        job = @queue.pop

        return nil unless job

        @mutex.synchronize do
          @in_processing[job.executor.id] = true
        end

        job
      end

      def complete(job)
        @mutex.synchronize do
          @in_processing.delete(job.executor.id)
        end
      end

      def clear
        @in_processing.clear
        @queue.clear
      end

      def stop
        @queue.close unless @queue.closed?
      end

      def wait
        while wait?
          Thread.pass
          sleep(0.01)
        end
      end

      private

      def wait?
        return false if Karafka::App.stopping?
        return false if @queue.closed?
        return false if @in_processing.empty?

        true
      end
    end
  end
end
