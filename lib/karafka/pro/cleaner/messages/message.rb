# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Cleaner
      # Cleaner messages components related enhancements
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

          # Cleans the message payload, headers, key and removes the deserialized data references
          # This is useful when working with big messages that take a lot of space.
          #
          # After the message content is no longer needed, it can be removed so it does not consume
          # space anymore.
          #
          # @param metadata [Boolean] should we also clean metadata alongside the payload. This can
          #   be useful when working with iterator and other things that may require only metadata
          #   available, while not payload. `true` by default.
          #
          # @note Cleaning of message means we also clean its metadata (headers and key)
          # @note Metadata cleaning (headers and key) can be disabled by setting the `metadata`
          #   argument to `false`.
          def clean!(metadata: true)
            @deserialized = false
            @raw_payload = false
            @payload = nil

            @metadata.clean! if metadata
          end
        end
      end
    end
  end
end
