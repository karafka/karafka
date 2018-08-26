# frozen_string_literal: true

module Karafka
  module Params
    # Simple metadata object that stores all non-message information received from Kafka cluster
    # while fetching the data
    class Metadata < Hash
      METHOD_ATTRIBUTES = %w[
        topic
        batch_size
        partition
        offset_lag
        group_id
        last_offset
        highwater_mark_offset
        offset_lag
        first_offset
      ].freeze

      private_constant :METHOD_ATTRIBUTES

      METHOD_ATTRIBUTES.each do |attr|
        # Defines a method call accessor to a particular hash field.
        define_method(attr) do
          self[attr]
        end
      end

      def unknown_last_offset?
        self['unknown_last_offset']
      end
    end
  end
end
