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
      module Filters
        # Throttler used to limit number of messages we can process in a given time interval
        # The tricky thing is, that even if we throttle on 100 messages, if we've reached 100, we
        # still need to indicate, that we throttle despite not receiving 101. Otherwise we will
        # not pause the partition and will fetch more data that we should not process.
        #
        # This is a special type of a filter that always throttles and makes us wait / seek if
        # anything is applied out.
        class Throttler
          include Karafka::Core::Helpers::Time

          # @return [Karafka::Messages::Message, nil] first throttled message or nil if nothing
          #   throttled
          attr_reader :cursor

          # @param limit [Integer] how many messages we can process in a given time
          # @param interval [Integer] interval in milliseconds for which we want to process
          def initialize(limit, interval)
            @limit = limit
            @interval = interval
            @requests = Hash.new { |h, k| h[k] = 0 }
            @applied = false
            @cursor = nil
          end

          # Limits number of messages to a range that we can process (if needed) and keeps track
          # of how many messages we've processed in a given time
          # @param messages [Array<Karafka::Messages::Message>] limits the number of messages to
          #   number we can accept in the context of throttling constraints
          def apply!(messages)
            @applied = false
            @cursor = nil
            @time = monotonic_now
            @requests.delete_if { |timestamp, _| timestamp < (@time - @interval) }
            values = @requests.values.sum
            accepted = 0

            messages.delete_if do |message|
              # +1 because of current
              @applied = (values + accepted + 1) > @limit

              @cursor = message if @applied && @cursor.nil?

              next true if @applied

              accepted += 1

              false
            end

            @requests[@time] += accepted
          end

          def action
            if applied?
              timeout.zero? ? :seek : :pause
            else
              :skip
            end
          end

          # @return [Boolean] in case of this filter, throttling always means filtering
          def applied?
            @applied
          end

          # @return [Integer] minimum number of milliseconds to wait before getting more messages
          #   so we are no longer throttled and so we can process at least one message
          def timeout
            timeout = @interval - (monotonic_now - @time)
            timeout < 0 ? 0 : timeout
          end
        end
      end
    end
  end
end
