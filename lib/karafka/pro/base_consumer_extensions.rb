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
    # Extensions to the base consumer that make it more pro and fancy
    #
    # @note In case of using lrj, manual pausing may not be the best idea as resume needs to happen
    #   after each batch is processed.
    #
    # They need to be added to the consumer via `#prepend`
    module BaseConsumerExtensions
      # Pause for tops 31 years
      MAX_PAUSE_TIME = 1_000_000_000_000

      private_constant :MAX_PAUSE_TIME

      # Pauses processing of a given partition until we're done with the processing
      # This ensures, that we can easily poll not reaching the `max.poll.interval`
      def on_prepare
        # Pause at the first message in a batch. That way in case of a crash, we will not loose
        # any messages
        pause(messages.first.offset, MAX_PAUSE_TIME) if topic.long_running_job?

        super
      end

      # After user code, we seek and un-pause our partition
      def on_consume
        # If anything went wrong here, we should not run any partition management as it's Karafka
        # core that will handle the backoff
        return unless super

        return unless topic.long_running_job?

        # Nothing to resume if it was revoked
        return if revoked?

        # Once processing is done, we move to the new offset based on commits
        seek(@seek_offset || messages.first.offset)
        resume
      end

      # Marks this consumer revoked state as true
      # This allows us for things like lrj to finish early as this state may change during lrj
      # execution
      def on_revoked
        @revoked = true
        super
      end

      # @return [Boolean] true if partition was revoked from the current consumer
      def revoked?
        @revoked || false
      end
    end
  end
end
