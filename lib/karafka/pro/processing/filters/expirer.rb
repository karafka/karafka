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
        end
      end
    end
  end
end
