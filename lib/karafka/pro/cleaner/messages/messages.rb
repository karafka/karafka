# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Cleaner
      module Messages
        # Extensions to the messages batch allowing for automatic cleaning of each message after
        # message is processed.
        module Messages
          # @param clean [Boolean] do we want to clean each message after we're done working with
          #   it.
          # @yield block we want to execute per each message
          #
          # @note Cleaning messages after we're done with each of them and did not fail does not
          #   affect any other functionalities. The only thing that is crucial is to make sure,
          #   that if DLQ is used, that we mark each message as consumed when using this API as
          #   otherwise a cleaned message may be dispatched and that should never happen
          def each(clean: false)
            @messages_array.each do |message|
              yield(message)

              next unless clean

              message.clean!
            end
          end
        end
      end
    end
  end
end
