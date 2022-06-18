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

      # Pauses processing of a given partition until we're done with the processing
      # This ensures, that we can easily poll not reaching the `max.poll.interval`
      def on_before_consume
        # Pause at the first message in a batch. That way in case of a crash, we will not loose
        # any messages
        return unless topic.long_running_job?

        pause(messages.first.offset, MAX_PAUSE_TIME)
      end

      # Runs extra logic after consumption that is related to handling long running jobs
      # @note This overwrites the '#on_after_consume' from the base consumer
      def on_after_consume
        # Nothing to do if we lost the partition
        return if revoked?

        if @consumption.success?
          pause_tracker.reset

          # We use the non-blocking one here. If someone needs the blocking one, can implement it
          # with manual offset management
          # Mark as consumed only if manual offset management is not on
          mark_as_consumed(messages.last) unless topic.manual_offset_management?

          # If this is not a long running job there is nothing for us to do here
          return unless topic.long_running_job?

          # Once processing is done, we move to the new offset based on commits
          # Here, in case manual offset management is off, we have the new proper offset of a
          # first message from another batch from `@seek_offset`. If manual offset management
          # is on, we move to place where the user indicated it was finished.
          seek(@seek_offset || messages.first.offset)
          resume
        else
          # If processing failed, we need to pause
          pause(@seek_offset || messages.first.offset)
        end
      end

      # Marks this consumer revoked state as true
      # This allows us for things like lrj to finish early as this state may change during lrj
      # execution
      def on_revoked
        # @note This may already be set to true if we tried to commit offsets and failed. In case
        # like this it will automatically be marked as revoked.
        @revoked = true
        super
      end
    end
  end
end
