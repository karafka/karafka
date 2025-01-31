# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # No features enabled.
      # No manual offset management
      # No long running jobs
      # Nothing. Just standard, automatic flow
      module Default
        include Base

        # Apply strategy for a non-feature based flow
        FEATURES = %i[].freeze

        # By default on all "before schedule" we just run instrumentation, nothing more
        %i[
          consume
          idle
          eofed
          revoked
          shutdown
        ].each do |action|
          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            # No actions needed for the standard flow here
            def handle_before_schedule_#{action}
              monitor.instrument('consumer.before_schedule_#{action}', caller: self)

              nil
            end
          RUBY
        end

        # Runs the post-creation, post-assignment code
        # @note It runs in the listener loop. Should **not** be used for anything heavy or
        #   with any potential errors. Mostly for initialization of states, etc.
        def handle_initialized
          monitor.instrument('consumer.initialize', caller: self)
          monitor.instrument('consumer.initialized', caller: self) do
            initialized
          end
        end

        # Marks message as consumed in an async way.
        #
        # @param message [Messages::Message] last successfully processed message.
        # @return [Boolean] true if we were able to mark the offset, false otherwise.
        #   False indicates that we were not able and that we have lost the partition.
        #
        # @note We keep track of this offset in case we would mark as consumed and got error when
        #   processing another message. In case like this we do not pause on the message we've
        #   already processed but rather at the next one. This applies to both sync and async
        #   versions of this method.
        def mark_as_consumed(message)
          # seek offset can be nil only in case `#seek` was invoked with offset reset request
          # In case like this we ignore marking
          return true if seek_offset.nil?
          # Ignore double markings of the same offset
          return true if (seek_offset - 1) == message.offset
          return false if revoked?
          return revoked? unless client.mark_as_consumed(message)

          self.seek_offset = message.offset + 1

          true
        end

        # Marks message as consumed in a sync way.
        #
        # @param message [Messages::Message] last successfully processed message.
        # @return [Boolean] true if we were able to mark the offset, false otherwise.
        #   False indicates that we were not able and that we have lost the partition.
        def mark_as_consumed!(message)
          # seek offset can be nil only in case `#seek` was invoked with offset reset request
          # In case like this we ignore marking
          return true if seek_offset.nil?
          # Ignore double markings of the same offset
          return true if (seek_offset - 1) == message.offset
          return false if revoked?

          return revoked? unless client.mark_as_consumed!(message)

          self.seek_offset = message.offset + 1

          true
        end

        # Triggers an async offset commit
        #
        # @param async [Boolean] should we use async (default) or sync commit
        # @return [Boolean] true if we still own the partition.
        # @note Due to its async nature, this may not fully represent the offset state in some
        #   edge cases (like for example going beyond max.poll.interval)
        def commit_offsets(async: true)
          # Do not commit if we already lost the assignment
          return false if revoked?
          return true if client.commit_offsets(async: async)

          # This will once more check the librdkafka revocation status and will revoke the
          # coordinator in case it was not revoked
          revoked?
        end

        # Triggers a synchronous offsets commit to Kafka
        #
        # @return [Boolean] true if we still own the partition, false otherwise.
        # @note This is fully synchronous, hence the result of this can be used in DB transactions
        #   etc as a way of making sure, that we still own the partition.
        def commit_offsets!
          commit_offsets(async: false)
        end

        # Increment number of attempts
        def handle_before_consume
          coordinator.pause_tracker.increment
        end

        # Runs the wrapping to execute appropriate action wrapped with the wrapper method code
        #
        # @param action [Symbol]
        # @param block [Proc]
        def handle_wrap(action, &block)
          monitor.instrument('consumer.wrap', caller: self)
          monitor.instrument('consumer.wrapped', caller: self) do
            wrap(action, &block)
          end
        end

        # Run the user consumption code
        def handle_consume
          monitor.instrument('consumer.consume', caller: self)
          monitor.instrument('consumer.consumed', caller: self) do
            consume
          end

          # Mark job as successful
          coordinator.success!(self)
        rescue StandardError => e
          coordinator.failure!(self, e)

          # Re-raise so reported in the consumer
          raise e
        ensure
          # We need to decrease number of jobs that this coordinator coordinates as it has finished
          coordinator.decrement(:consume)
        end

        # Standard flow marks work as consumed and moves on if everything went ok.
        # If there was a processing error, we will pause and continue from the next message
        # (next that is +1 from the last one that was successfully marked as consumed)
        def handle_after_consume
          return if revoked?

          if coordinator.success?
            coordinator.pause_tracker.reset

            # We should not move the offset automatically when the partition was paused
            # If we would not do this upon a revocation during the pause time, a different process
            # would pick not from the place where we paused but from the offset that would be
            # automatically committed here
            return if coordinator.manual_pause?

            mark_as_consumed(messages.last)
          else
            retry_after_pause
          end
        end

        # Code that should run on idle runs without messages available
        def handle_idle
          nil
        ensure
          coordinator.decrement(:idle)
        end

        # Runs the consumer `#eofed` method with reporting
        def handle_eofed
          monitor.instrument('consumer.eof', caller: self)
          monitor.instrument('consumer.eofed', caller: self) do
            eofed
          end
        ensure
          coordinator.decrement(:eofed)
        end

        # We need to always un-pause the processing in case we have lost a given partition.
        # Otherwise the underlying librdkafka would not know we may want to continue processing and
        # the pause could in theory last forever
        def handle_revoked
          resume

          coordinator.revoke

          monitor.instrument('consumer.revoke', caller: self)
          monitor.instrument('consumer.revoked', caller: self) do
            revoked
          end
        ensure
          coordinator.decrement(:revoked)
        end

        # Runs the shutdown code
        def handle_shutdown
          monitor.instrument('consumer.shutting_down', caller: self)
          monitor.instrument('consumer.shutdown', caller: self) do
            shutdown
          end
        ensure
          coordinator.decrement(:shutdown)
        end
      end
    end
  end
end
