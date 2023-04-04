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
      # Throttler used to limit number of messages we can process in a given time interval
      # The tricky thing is, that even if we throttle on 100 messages, if we've reached 100, we
      # still need to indicate, that we throttle despite not receiving 101. Otherwise we will
      # not pause the partition and will fetch more data that we should not process.
      class Throttler
        include Karafka::Core::Helpers::Time

        # @return [Karafka::Messages::Message, nil] first throttled message or nil if nothing
        #   throttled
        attr_reader :message

        # @param limit [Integer] how many messages we can process in a given time
        # @param interval [Integer] interval in milliseconds for which we want to process
        def initialize(limit, interval)
          @limit = limit
          @interval = interval
          @requests = Hash.new { |h, k| h[k] = 0 }
          @throttled = false
          @message = nil
        end

        # Limits number of messages to a range that we can process (if needed) and keeps track
        # of how many messages we've processed in a given time
        # @param messages [Array<Karafka::Messages::Message>] limits the number of messages to
        #   number we can accept in the context of throttling constraints
        def throttle!(messages)
          @throttled = false
          @message = nil
          @time = monotonic_now
          @requests.delete_if { |timestamp, _| timestamp < (@time - @interval) }
          values = @requests.values.sum
          accepted = 0

          messages.delete_if do |message|
            # +1 because of current
            @throttled = (values + accepted + 1) > @limit

            @message = message if @throttled && @message.nil?

            next true if @throttled

            accepted += 1

            false
          end

          @requests[@time] += accepted
        end

        # @return [Boolean] true if we had to throttle messages for processing
        def throttled?
          @throttled
        end

        # @return [Boolean] did this throttle expired. Throttling expires in case we throttled but
        #   enough time have passed and our pause distance is less than zero. In cases like this
        #   we do not pause processing but we need to seek to a correct offset
        def expired?
          @throttled && timeout <= 0
        end

        # @return [Integer] minimum number of milliseconds to wait before getting more messages
        #   so we are no longer throttled and so we can process at least one message
        def timeout
          @interval - (monotonic_now - @time)
        end
      end
    end
  end
end
