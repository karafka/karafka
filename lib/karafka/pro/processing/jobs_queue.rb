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
        include Core::Helpers::Time

        attr_accessor :in_processing

        # How long should we keep async lock (31 years)
        WAIT_TIMEOUT = 10_000_000_000

        private_constant :WAIT_TIMEOUT

        # @return [Karafka::Pro::Processing::JobsQueue]
        def initialize
          super

          @in_waiting = Hash.new { |h, k| h[k] = [] }
          @locks = Hash.new { |h, k| h[k] = {} }

          @statistics[:waiting] = 0
        end

        # Registers semaphore and a lock hash
        #
        # @param group_id [String]
        def register(group_id)
          super
          @mutex.synchronize do
            @locks[group_id]
          end
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

            @statistics[:waiting] += 1

            group << job
          end
        end

        # Method for unlocking the given subscription group queue space that was locked with a
        # given job that was **not** added to the queue but used via `#lock`.
        #
        # @param job [Jobs::Base] job that locked the queue
        def unlock(job)
          @mutex.synchronize do
            @statistics[:waiting] -= 1

            return if @in_waiting[job.group_id].delete(job)

            # This should never happen. It means there was a job being unlocked that was never
            # locked in the first place
            raise(Errors::JobsQueueSynchronizationError, job.group_id)
          end
        end

        # Allows for explicit locking of the queue of a given subscription group.
        #
        # This can be used for cross-topic synchronization.
        #
        # @param group_id [String] id of the group we want to lock
        # @param id [Object] unique id we want to use to identify our lock
        # @param timeout [Integer] number of ms how long this lock should be valid. Useful for
        #   auto-expiring locks used to delay further processing without explicit pausing on
        #   the consumer
        #
        # @note We do not raise `Errors::JobsQueueSynchronizationError` similar to `#lock` here
        #   because we want to have ability to prolong time limited locks
        def lock_async(group_id, id, timeout: WAIT_TIMEOUT)
          return if @queue.closed?

          @mutex.synchronize do
            group = @locks[group_id]

            group[id] = monotonic_now + timeout
          end
        end

        # Allows for explicit unlocking of locked queue of a group
        #
        # @param group_id [String] id of the group we want to unlock
        # @param id [Object] unique id we want to use to identify our lock
        #
        def unlock_async(group_id, id)
          @mutex.synchronize do
            if @locks[group_id].delete(id)
              tick(group_id)

              return
            end

            raise(Errors::JobsQueueSynchronizationError, [group_id, id])
          end
        end

        # Clears the processing states for a provided group. Useful when a recovery happens and we
        # need to clean up state but only for a given subscription group.
        #
        # @param group_id [String]
        def clear(group_id)
          @mutex.synchronize do
            @in_processing[group_id].clear

            @statistics[:waiting] -= @in_waiting[group_id].size
            @in_waiting[group_id].clear
            @locks[group_id].clear

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
              @in_waiting[group_id].empty? &&
              !locked_async?(group_id)
          end
        end

        private

        # Tells us if given group is locked
        #
        # @param group_id [String] id of the group in which we're interested.
        # @return [Boolean] true if there are any active locks on the group, otherwise false
        def locked_async?(group_id)
          return false if @locks[group_id].empty?

          @locks[group_id].delete_if { |_, wait_timeout| wait_timeout < monotonic_now }

          !@locks.empty?
        end

        # @param group_id [String] id of the group in which jobs we're interested.
        # @return [Boolean] should we keep waiting or not
        # @note We do not wait for non-blocking jobs. Their flow should allow for `poll` running
        #   as they may exceed `max.poll.interval`
        def wait?(group_id)
          return true unless @in_processing[group_id].all?(&:non_blocking?)
          return true unless @in_waiting[group_id].all?(&:non_blocking?)

          locked_async?(group_id)
        end
      end
    end
  end
end
