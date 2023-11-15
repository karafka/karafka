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
      # Enhanced processing queue that provides ability to build complex work-distribution
      # schedulers dedicated to particular job types
      #
      # Aside from the OSS queue capabilities it allows for jobless locking for advanced schedulers
      class JobsQueue < Karafka::Processing::JobsQueue
        attr_accessor :in_processing

        # @return [Karafka::Pro::Processing::JobsQueue]
        def initialize
          super
          @in_waiting = Hash.new { |h, k| h[k] = [] }
          @in_waiting_count = 0
        end

        # Returns number of jobs that are either enqueued or in processing (but not finished) or
        #   in waiting. All of those jobs need to finish.
        #
        # @return [Integer] number of elements in the queue or waiting to go there or being
        #   processed
        # @note Using `#pop` won't decrease this number as only marking job as completed does this
        def size
          @in_processing_count + @in_waiting_count
        end

        # Method that allows us to lock queue on a given subscription group without enqueuing the a
        # job. This can be used when building complex schedulers that want to postpone enqueuing
        # before certain conditions are met.
        #
        # @param job [Jobs::Base] job used for locking
        def lock(job)
          @mutex.synchronize do
            group = @in_waiting[job.group_id]

            # This should never happen. Same job should not be locked twice
            raise(Errors::JobsQueueSynchronizationError, job.group_id) if group.include?(job)

            @in_waiting_count += 1
            group << job
          end
        end

        # Method for unlocking the given subscription group queue space that was locked with a
        # given job that was **not** added to the queue but used via `#lock`.
        #
        # @param job [Jobs::Base] job that locked the queue
        def unlock(job)
          @mutex.synchronize do
            @in_waiting_count -= 1

            return if @in_waiting[job.group_id].delete(job)

            # This should never happen. It means there was a job being unlocked that was never
            # locked in the first place
            raise(Errors::JobsQueueSynchronizationError, job.group_id)
          end
        end

        # Clears the processing states for a provided group. Useful when a recovery happens and we
        # need to clean up state but only for a given subscription group.
        #
        # @param group_id [String]
        def clear(group_id)
          @mutex.synchronize do
            @in_processing_count -= @in_processing[group_id].size
            @in_processing[group_id].clear

            @in_waiting_count -= @in_waiting[group_id].size
            @in_waiting[group_id].clear

            # We unlock it just in case it was blocked when clearing started
            tick(group_id)
          end
        end

        # @param group_id [String]
        #
        # @return [Boolean] tell us if we have anything in the processing (or for processing) from
        # a given group.
        def empty?(group_id)
          @mutex.synchronize do
            @in_processing[group_id].empty? &&
              @in_waiting[group_id].empty?
          end
        end

        # - `busy` - number of jobs that are currently being processed (active work)
        # - `enqueued` - number of jobs in the queue that are waiting to be picked up by a worker
        #
        # @return [Hash] hash with basic usage statistics of this queue.
        def statistics
          {
            busy: size - @queue.size - @in_waiting_count,
            enqueued: @queue.size + @in_waiting_count
          }.freeze
        end

        private

        # @param group_id [String] id of the group in which jobs we're interested.
        # @return [Boolean] should we keep waiting or not
        # @note We do not wait for non-blocking jobs. Their flow should allow for `poll` running
        #   as they may exceed `max.poll.interval`
        def wait?(group_id)
          !(
            @in_processing[group_id].all?(&:non_blocking?) &&
            @in_waiting[group_id].all?(&:non_blocking?)
          )
        end
      end
    end
  end
end
