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
    module ScheduledMessages
      # Serializers used to build payloads (if applicable) for dispatch
      # @note We only deal with states payload. Other payloads are not ours but end users.
      class Serializer
        # @param tracker [Tracker] tracker based on which we build the state
        # @return [String] compressed payload with the state details
        def state(tracker)
          data = {
            schema_version: ScheduledMessages::STATES_SCHEMA_VERSION,
            state: tracker.state,
            daily: tracker.daily
          }

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
