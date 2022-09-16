# frozen_string_literal: true

module Karafka
  module Processing
    # This is the key work component for Karafka jobs distribution. It provides API for running
    # jobs in parallel while operating within more than one subscription group.
    #
    # We need to take into consideration fact, that more than one subscription group can operate
    # on this queue, that's why internally we keep track of processing per group.
    #
    # We work with the assumption, that partitions data is evenly distributed.
    class JobsQueue
      # @return [Karafka::Processing::JobsQueue]
      def initialize
        @queue = Queue.new
        # Those queues will act as semaphores internally. Since we need an indicator for waiting
        # we could use Thread.pass but this is expensive. Instead we can just lock until any
        # of the workers finishes their work and we can re-check. This means that in the worse
        # scenario, we will context switch 10 times per poll instead of getting this thread
        # scheduled by Ruby hundreds of thousands of times per group.
        # We cannot use a single semaphore as it could potentially block in listeners that should
        # process with their data and also could unlock when a given group needs to remain locked
        @semaphores = Hash.new { |h, k| h[k] = Queue.new }
        @in_processing = Hash.new { |h, k| h[k] = [] }
        @mutex = Mutex.new
      end

      # Returns number of jobs that are either enqueued or in processing (but not finished)
      # @return [Integer] number of elements in the queue
      # @note Using `#pop` won't decrease this number as only marking job as completed does this
      def size
        @in_processing.values.map(&:size).sum
      end

      # Adds the job to the internal main queue, scheduling it for execution in a worker and marks
      # this job as in processing pipeline.
      #
      # @param job [Jobs::Base] job that we want to run
      def <<(job)
        # We do not push the job if the queue is closed as it means that it would anyhow not be
        # executed
        return if @queue.closed?

        @mutex.synchronize do
          group = @in_processing[job.group_id]

          raise(Errors::JobsQueueSynchronizationError, job.group_id) if group.include?(job)

          group << job
        end

        @queue << job
      end

      # @return [Jobs::Base, nil] waits for a job from the main queue and returns it once available
      #   or returns nil if the queue has been stopped and there won't be anything more to process
      #   ever.
      # @note This command is blocking and will wait until any job is available on the main queue
      def pop
        @queue.pop
      end

      # Causes the wait lock to re-check the lock conditions and potential unlock.
      # @param group_id [String] id of the group we want to unlock for one tick
      # @note This does not release the wait lock. It just causes a conditions recheck
      def tick(group_id)
        @semaphores[group_id] << true
      end

      # Marks a given job from a given group as completed. When there are no more jobs from a given
      # group to be executed, we won't wait.
      #
      # @param [Jobs::Base] job that was completed
      def complete(job)
        @mutex.synchronize do
          @in_processing[job.group_id].delete(job)
          tick(job.group_id)
        end
      end

      # Clears the processing states for a provided group. Useful when a recovery happens and we
      # need to clean up state but only for a given subscription group.
      #
      # @param group_id [String]
      def clear(group_id)
        @mutex.synchronize do
          @in_processing[group_id].clear
          # We unlock it just in case it was blocked when clearing started
          tick(group_id)
        end
      end

      # Stops the whole processing queue.
      def close
        @mutex.synchronize do
          return if @queue.closed?

          @queue.close
          @semaphores.values.each(&:close)
        end
      end

      # @param group_id [String]
      #
      # @return [Boolean] tell us if we have anything in the processing (or for processing) from
      # a given group.
      def empty?(group_id)
        @in_processing[group_id].empty?
      end

      # Blocks when there are things in the queue in a given group and waits until all the blocking
      #   jobs from a given group are completed
      #
      # @param group_id [String] id of the group in which jobs we're interested.
      # @note This method is blocking.
      def wait(group_id)
        # Go doing other things while we cannot process and wait for anyone to finish their work
        # and re-check the wait status
        @semaphores[group_id].pop while wait?(group_id)
      end

      # - `processing` - number of jobs that are currently being processed (active work)
      # - `enqueued` - number of jobs in the queue that are waiting to be picked up by a worker
      #
      # @return [Hash] hash with basic usage statistics of this queue.
      def statistics
        {
          processing: size - @queue.size,
          enqueued: @queue.size
        }.freeze
      end

      private

      # @param group_id [String] id of the group in which jobs we're interested.
      # @return [Boolean] should we keep waiting or not
      # @note We do not wait for non-blocking jobs. Their flow should allow for `poll` running
      #   as they may exceed `max.poll.interval`
      def wait?(group_id)
        !@in_processing[group_id].all?(&:non_blocking?)
      end
    end
  end
end
