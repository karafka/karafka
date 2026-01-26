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
    module Routing
      module Features
        # This feature allows for saving and retrieving offset metadata with custom deserialization
        # support. It allows for storing extra data during commits that can be then used to alter
        # the processing flow after a rebalance.
        #
        # @note Because this feature has zero performance impact and makes no queries to Kafka
        #   unless requested, it is always enabled.
        class OffsetMetadata < Base
          # Empty string not to create it on each deserialization
          EMPTY_STRING = ""

          # Default deserializer just ensures we always get a string as without metadata by
          # default it would be nil
          STRING_DESERIALIZER = ->(raw_metadata) { raw_metadata || EMPTY_STRING }.freeze

          private_constant :STRING_DESERIALIZER, :EMPTY_STRING

          # Commit Metadata API extensions
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @offset_metadata = nil
            end

            # @param cache [Boolean] should we cache the response until rebalance
            # @param deserializer [#call] deserializer that will get raw data and should return
            #   deserialized metadata
            # @return [Config] this feature config
            def offset_metadata(cache: true, deserializer: STRING_DESERIALIZER)
              @offset_metadata ||= Config.new(
                active: true,
                cache: cache,
                deserializer: deserializer
              )
            end

            # @return [true] is offset metadata active (it always is)
            def offset_metadata?
              offset_metadata.active?
            end

            # @return [Hash] topic with all its native configuration options plus offset metadata
            #   settings
            def to_h
              super.merge(
                offset_metadata: offset_metadata.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
