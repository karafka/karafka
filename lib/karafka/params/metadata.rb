# frozen_string_literal: true

module Karafka
  module Params
    # Single message / params metadata details that can be accessed without the need for the
    # payload deserialization
    class Metadata < Hash
      # Attributes that should be accessible as methods as well (not only hash)
      METHOD_ATTRIBUTES = %w[
        create_time
        headers
        is_control_record
        key
        offset
        deserializer
        partition
        receive_time
        topic
      ].freeze

      private_constant :METHOD_ATTRIBUTES

      METHOD_ATTRIBUTES.each do |attr|
        # Defines a method call accessor to a particular hash field.
        define_method(attr) do
          self[attr]
        end
      end
    end
  end
end
