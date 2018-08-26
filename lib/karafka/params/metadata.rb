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
        # @note Won't work for complex key names that contain spaces, etc
        # @param key [Symbol] name of a field that we want to retrieve with a method call
        # @example
        #   key_attr_reader :example
        #   params.example #=> 'my example value'
        define_method(attr) do
          self[attr]
        end
      end

      def unknown_last_offset?
        false
      end
    end
  end
end
