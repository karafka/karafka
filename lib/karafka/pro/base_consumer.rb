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
        return unless topic.long_running_job?

        # This ensures, that when running LRJ with VP, things operate as expected
        coordinator.on_started do |first_group_message|
          # Pause at the first message in a batch. That way in case of a crash, we will not loose
          # any messages
          pause(first_group_message.offset, MAX_PAUSE_TIME)
        end
      end

      # Runs extra logic after consumption that is related to handling long-running jobs
      # @note This overwrites the '#on_after_consume' from the base consumer
      def on_after_consume
        coordinator.on_finished do |first_group_message, last_group_message|
          on_after_consume_regular(first_group_message, last_group_message)
        end
      end

      private

      # Handles the post-consumption flow depending on topic settings
      #
      # @param first_message [Karafka::Messages::Message]
      # @param last_message [Karafka::Messages::Message]
      def on_after_consume_regular(first_message, last_message)
        if coordinator.success?
          coordinator.pause_tracker.reset

          # We use the non-blocking one here. If someone needs the blocking one, can implement it
          # with manual offset management
          # Mark as consumed only if manual offset management is not on
          mark_as_consumed(last_message) unless topic.manual_offset_management? || revoked?

          # If this is not a long-running job there is nothing for us to do here
          return unless topic.long_running_job?

          # Once processing is done, we move to the new offset based on commits
          # Here, in case manual offset management is off, we have the new proper offset of a
          # first message from another batch from `@seek_offset`. If manual offset management
          # is on, we move to place where the user indicated it was finished. This can create an
          # interesting (yet valid) corner case, where with manual offset management on and no
          # marking as consumed, we end up with an infinite loop processing same messages over and
          # over again
          seek(@seek_offset || first_message.offset)

          resume
        else
          # If processing failed, we need to pause
          pause(@seek_offset || first_message.offset)
        end
      end
    end
  end
end
