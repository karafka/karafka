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
    module Cleaner
      module Messages
        # Extensions to the message that allow for granular memory control on a per message basis
        module Message
          # @return [Object] lazy-deserialized data (deserialized upon first request)
          def payload
            # If message has already been cleaned, it cannot be deserialized again
            cleaned? ? raise(Errors::MessageCleanedError) : super
          end

          # @return [Boolean] true if the message has been cleaned
          def cleaned?
            @raw_payload == false
          end

          # Cleans the message payload and removes the deserialized data references
          # This is useful when working with big messages that take a lot of space.
          #
          # After the message content is no longer needed, it can be removed so it does not consume
          # space anymore.
          def clean!
            @deserialized = false
            @raw_payload = false
            @payload = nil
          end
        end
      end
    end
  end
end
