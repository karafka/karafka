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
      # Offset Metadata support on the processing side
      module OffsetMetadata
        # Extra API methods for offset metadata fetching
        # @note Part of this feature API is embedded directly into the strategies because it alters
        #   how marking methods (`#mark_as_consumed` and `#mark_as_consumed!`) operate. Because
        #   of that, they had to be embedded into the strategies.
        module Consumer
          # @param cache [Boolean] should we use cached result if present (true by default)
          # @return [false, Object] false in case we do not own the partition anymore or
          #   deserialized metadata based on the deserializer
          # @note Caching is on as the assumption here is, that most of the time user will be
          #   interested only in the offset metadata that "came" from the time prior to the
          #   rebalance. That is because the rest of the metadata (current) is created and
          #   controlled by the user himself, thus there is no need to retrieve it. In case this
          #   is not true and user wants to always get the Kafka metadata, `cache` value of this
          #   feature can be set to false.
          def offset_metadata(cache: true)
            return false if revoked?

            Fetcher.find(topic, partition, cache: cache)
          end

          alias committed_offset_metadata offset_metadata
        end
      end
    end
  end
end
