# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
          EMPTY_STRING = ''

          # Default deserializer just ensures we always get a string as without metadata by
          # default it would be nil
          STRING_DESERIALIZER = ->(raw_metadata) { raw_metadata || EMPTY_STRING }.freeze

          private_constant :STRING_DESERIALIZER, :EMPTY_STRING

          # Commit Metadata API extensions
          module Topic
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
