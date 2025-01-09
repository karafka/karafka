# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
          @async_locking = false

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
        # @param lock_id [Object] unique id we want to use to identify our lock
        # @param timeout [Integer] number of ms how long this lock should be valid. Useful for
        #   auto-expiring locks used to delay further processing without explicit pausing on
        #   the consumer
        #
        # @note We do not raise `Errors::JobsQueueSynchronizationError` similar to `#lock` here
        #   because we want to have ability to prolong time limited locks
        def lock_async(group_id, lock_id, timeout: WAIT_TIMEOUT)
          return if @queue.closed?

          @async_locking = true

          @mutex.synchronize do
            @locks[group_id][lock_id] = monotonic_now + timeout

            # We need to tick so our new time sensitive lock can reload time constraints on sleep
            tick(group_id)
          end
        end

        # Allows for explicit unlocking of locked queue of a group
        #
        # @param group_id [String] id of the group we want to unlock
        # @param lock_id [Object] unique id we want to use to identify our lock
        #
        def unlock_async(group_id, lock_id)
          @mutex.synchronize do
            if @locks[group_id].delete(lock_id)
              tick(group_id)

              return
            end

            raise(Errors::JobsQueueSynchronizationError, [group_id, lock_id])
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
            @async_locking = false

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

        # Blocks when there are things in the queue in a given group and waits until all the
        #   blocking jobs from a given group are completed or any of the locks times out
        # @param group_id [String] id of the group in which jobs we're interested.
        # @see `Karafka::Processing::JobsQueue`
        #
        # @note Because checking that async locking is on happens on regular ticking, first lock
        #   on a group can take up to one tick. That is expected.
        #
        # @note This implementation takes into consideration temporary async locks that can happen.
        #   Thanks to the fact that we use the minimum lock time as a timeout, we do not have to
        #   wait a whole ticking period to unlock async locks.
        def wait(group_id)
          return super unless @async_locking

          # We do not generalize this flow because this one is more expensive as it has to allocate
          # extra objects. That's why we only use it when locks are actually in use
          base_interval = tick_interval / 1_000.0

          while wait?(group_id)
            yield if block_given?

            now = monotonic_now

            wait_times = @locks[group_id].values.map! do |lock_time|
              # Convert ms to seconds, seconds are required by Ruby queue engine
              (lock_time - now) / 1_000
            end

            wait_times.delete_if(&:negative?)
            wait_times << base_interval

            @semaphores.fetch(group_id).pop(timeout: wait_times.min)
          end
        end

        private

        # Tells us if given group is locked
        #
        # @param group_id [String] id of the group in which we're interested.
        # @return [Boolean] true if there are any active locks on the group, otherwise false
        def locked_async?(group_id)
          return false unless @async_locking

          group = @locks[group_id]

          return false if group.empty?

          now = monotonic_now

          group.delete_if { |_, wait_timeout| wait_timeout < now }

          !group.empty?
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
