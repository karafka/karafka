# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Filters
        # Expirer for removing too old messages.
        # It never moves offsets in any way and does not impact the processing flow. It always
        # runs `:skip` action.
        class Expirer < Base
          # @param ttl [Integer] maximum age of a message (in ms)
          def initialize(ttl)
            super()

            @ttl = ttl
          end

          # Removes too old messages
          #
          # @param messages [Array<Karafka::Messages::Message>]
          def apply!(messages)
            @applied = false

            # Time on message is in seconds with ms precision, so we need to convert the ttl that
            # is in ms to this format
            border = ::Time.now.utc - @ttl / 1_000.to_f

            messages.delete_if do |message|
              too_old = message.timestamp < border

              @applied = true if too_old

              too_old
            end
          end

          # @return [nil] this filter does not deal with timeouts
          def timeout
            nil
          end
        end
      end
    end
  end
end
