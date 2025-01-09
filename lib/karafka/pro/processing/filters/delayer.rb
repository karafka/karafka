# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Filters
        # A filter that allows us to delay processing by pausing until time is right.
        class Delayer < Base
          # @param delay [Integer] ms delay / minimum age of each message we want to process
          def initialize(delay)
            super()

            @delay = delay
          end

          # Removes too young messages
          #
          # @param messages [Array<Karafka::Messages::Message>]
          def apply!(messages)
            @applied = false
            @cursor = nil

            # Time on message is in seconds with ms precision, so we need to convert the ttl that
            # is in ms to this format
            border = ::Time.now.utc - @delay / 1_000.0

            messages.delete_if do |message|
              too_young = message.timestamp > border

              if too_young
                @applied = true

                @cursor ||= message
              end

              @applied
            end
          end

          # @return [Integer] timeout delay in ms
          def timeout
            return 0 unless @cursor

            timeout = (@delay / 1_000.0) - (::Time.now.utc - @cursor.timestamp)

            timeout <= 0 ? 0 : timeout * 1_000
          end

          # @return [Symbol] action to take on post-filtering
          def action
            return :skip unless applied?

            timeout <= 0 ? :seek : :pause
          end
        end
      end
    end
  end
end
