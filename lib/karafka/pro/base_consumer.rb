# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    # Karafka PRO consumer.
    #
    # If you use PRO, all your consumers should inherit (indirectly) from it.
    #
    # @note In case of using lrj, manual pausing may not be the best idea as resume needs to happen
    #   after each batch is processed.
    class BaseConsumer < Karafka::BaseConsumer
      # Pause for tops 31 years
      MAX_PAUSE_TIME = 1_000_000_000_000

      private_constant :MAX_PAUSE_TIME

      # Pauses processing of a given partition until we're done with the processing.
      # This ensures, that we can easily poll not reaching the `max.poll.interval`
      # @note This needs to happen in the listener thread, because we cannot wait on this being
      #   executed in the workers. Workers may be already running some LRJ jobs that are blocking
      #   all the threads until finished, yet unless we pause the incoming partitions information,
      #   we may be kicked out of the consumer group due to not polling often enough
      def on_before_enqueue
        return unless topic.long_running_job?

        # This ensures that when running LRJ with VP, things operate as expected run only once
        # for all the virtual partitions collectively
        coordinator.on_enqueued do
          # Pause at the first message in a batch. That way in case of a crash, we will not loose
          # any messages.
          #
          # For VP it applies the same way and since VP cannot be used with MOM we should not have
          # any edge cases here.
          pause(coordinator.seek_offset, MAX_PAUSE_TIME)
        end
      end

      # Runs extra logic after consumption that is related to handling long-running jobs
      # @note This overwrites the '#on_after_consume' from the base consumer
      def on_after_consume
        coordinator.on_finished do |last_group_message|
          on_after_consume_regular(last_group_message)
        end
      end

      # Trigger method for running on partition revocation.
      #
      # @private
      def on_revoked
        # We do not want to resume on revocation in case of a LRJ.
        # For LRJ we resume after the successful processing or do a backoff pause in case of a
        # failure. Double non-blocking resume could cause problems in coordination.
        resume unless topic.long_running_job?

        coordinator.revoke

        Karafka.monitor.instrument('consumer.revoked', caller: self) do
          revoked
        end
      rescue StandardError => e
        Karafka.monitor.instrument(
          'error.occurred',
          error: e,
          caller: self,
          type: 'consumer.revoked.error'
        )
      end

      private

      # Handles the post-consumption flow depending on topic settings
      #
      # @param last_group_message [Karafka::Messages::Message]
      def on_after_consume_regular(last_group_message)
        if coordinator.success?
          coordinator.pause_tracker.reset

          # We use the non-blocking one here. If someone needs the blocking one, can implement it
          # with manual offset management
          # Mark as consumed only if manual offset management is not on
          mark_as_consumed(last_group_message) unless topic.manual_offset_management? || revoked?

          # If this is not a long-running job there is nothing for us to do here
          return unless topic.long_running_job?

          seek(coordinator.seek_offset) unless revoked?

          resume
        else
          # If processing failed, we need to pause
          # For long running job this will overwrite the default never-ending pause and will cause
          # the processing to keep going after the error backoff
          pause(coordinator.seek_offset)
        end
      end
    end
  end
end
