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
            def offset_metadata(cache: Undefined, deserializer: Undefined)
              @offset_metadata ||= Config.new(active: false, cache: true, deserializer: STRING_DESERIALIZER)
              return @offset_metadata if cache != Undefined && deserializer != Undefined

              @offset_metadata.active = true
              @offset_metadata.cache = cache unless cache == Undefined
              @offset_metadata.deserializer = deserializer unless deserializer == Undefined
              @offset_metadata
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
