# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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

          alias_method :committed_offset_metadata, :offset_metadata
        end
      end
    end
  end
end
