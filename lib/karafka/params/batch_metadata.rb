# frozen_string_literal: true

module Karafka
  module Params
    # Simple batch metadata object that stores all non-message information received from Kafka
    # cluster while fetching the data
    # @note This metadata object refers to per batch metadata, not `#params.metadata`
    class BatchMetadata < Hash
      # Attributes that should be accessible as methods as well (not only hash)
      METHOD_ATTRIBUTES = %w[
        batch_size
        first_offset
        highwater_mark_offset
        unknown_last_offset
        last_offset
        offset_lag
        deserializer
        partition
        topic
      ].freeze

      private_constant :METHOD_ATTRIBUTES

      METHOD_ATTRIBUTES.each do |attr|
        # Defines a method call accessor to a particular hash field.
        define_method(attr) do
          self[attr]
        end
      end

      # @return [Boolean] is the last offset known or unknown
      def unknown_last_offset?
        self['unknown_last_offset']
      end
    end
  end
end
