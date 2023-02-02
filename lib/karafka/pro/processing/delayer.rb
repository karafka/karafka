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
      # Component responsible for delated execution. It keeps track of the messages timestamps and
      # based on that issues a "recommendation" to remove certain too young messages from the
      # processing as well as issues info on how long we should pause and on what offset
      class Delayer
        include ::Karafka::Core::Helpers::Time

        # Lowest delayed offset from which we should start or false if not limiting
        attr_reader :last_processed

        def initialize
          @mutex = Mutex.new
        end

        # Starts delayer from coordinator and resets its internal state
        def start
          @started_at = float_now * 1_000
          @backoff = Float::INFINITY
          @limited = false
          @last_processed = false
        end

        # Sets up the delay and wait based on the topic in which this delayer operates
        # @param delay_for [Integer] lag in between message timestamp and its processing
        # @param max_wait_time [Integer] topic max wait time needed to align the lag
        def configure(delay_for, max_wait_time)
          @delay_for = delay_for
          @max_wait_time = max_wait_time
        end

        # @param message [::Karafka::Messages::Message] message we're checking
        # @return [Boolean] should given message be filtered because it is too young
        def filter?(message)
          memoize_first_encountered(message)

          lag = compute_lag(message)

          # If lag is negative, it means that message is not too young
          if lag <= 0
            memoize_last_processed(message)

            false
          else
            @limited = true

            memoize_smallest_lag(lag)

            true
          end
        end

        # @return [Boolean] true if delayer limited the scope of processed message (even by one)
        def limited?
          @limited
        end

        # Seek offset from which we should start after the delay pause
        # In case we did any processed, we pick the last message that was processed and move to the
        # another one.
        # In case all our messages were too young, we start from where we started previously
        # @return [Integer] seek offset
        def seek_offset
          @last_processed ? @last_processed.offset + 1 : @first_encountered.offset
        end

        # @return [Integer] number of ms we should backoff. Since our resolution is around the
        #   `max_wait_time` we use it as well to back off. That way we do not resume too early nor
        #   too late but more or less on the spot.
        def backoff
          backoff = @backoff - @max_wait_time
          backoff < @max_wait_time ? (@max_wait_time / 2) : backoff
        end

        private

        # Remembers the first message we have encountered.
        #
        # Because of things like virtual partitions, we need to resolve the offsets and not just
        # rely on the first message that is going to be shipped to us
        #
        # @param message [Karafka::Messages::Message]
        def memoize_first_encountered(message)
          # This is needed to compensate for future usage of virtual partitions as their
          # cross virtual partition order is not deterministic
          @mutex.synchronize do
            @first_encountered ||= message

            # Only overwrite first message tracking if there is a different one that has an
            # earlier offset. This can happen in case of virtual partitioning
            break if @first_encountered.offset < message.offset

            @first_encountered = message
          end
        end

        # Remembers the last message (highest offset) that was not filtered
        #
        # Because of things like virtual partitions, we need to resolve the offsets and not just
        # rely on the last message that is going to be shipped to us.
        # @param message [Karafka::Messages::Message]
        def memoize_last_processed(message)
          @mutex.synchronize do
            @last_processed ||= message

            break if @last_processed.offset > message.offset

            @last_processed = message
          end
        end

        # Remembers the smallest lag from all the messages so we can compute pause that will be
        # just enough. Not too long and not too short
        #
        # @param lag [Integer]
        def memoize_smallest_lag(lag)
          @mutex.synchronize do
            break if @lag <= lag

            @lag = lag
          end
        end

        # Computes the lag of the message against our expectation
        #
        # @param message [Karafka::Messages::Message]
        def compute_lag(message)
          (message.metadata.timestamp.to_f * 1_000) + @delay_for - @started_at
        end
      end
    end
  end
end
