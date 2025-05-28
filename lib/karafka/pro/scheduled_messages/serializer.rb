# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Serializers used to build payloads (if applicable) for dispatch
      # @note We only deal with states payload. Other payloads are not ours but end users.
      class Serializer
        include ::Karafka::Core::Helpers::Time

        # @param tracker [Tracker] tracker based on which we build the state
        # @return [String] compressed payload with the state details
        def state(tracker)
          data = {
            schema_version: ScheduledMessages::STATES_SCHEMA_VERSION,
            dispatched_at: float_now
          }.merge(tracker.to_h)

          compress(
            serialize(data)
          )
        end

        private

        # @param hash [Hash] hash to cast to json
        # @return [String] json hash
        def serialize(hash)
          hash.to_json
        end

        # Compresses the provided data
        #
        # @param data [String] data to compress
        # @return [String] compressed data
        def compress(data)
          Zlib::Deflate.deflate(data)
        end
      end
    end
  end
end
