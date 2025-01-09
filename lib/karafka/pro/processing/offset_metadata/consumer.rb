# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
