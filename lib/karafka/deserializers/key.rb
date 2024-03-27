# frozen_string_literal: true

module Karafka
  module Deserializers
    # Default message key deserializer
    class Key
      # @param metadata [Karafka::Messages::Metadata] metadata object from which we obtain the
      #   `#raw_key`
      # @return [String, nil] expected message key in a string format or nil if no key
      def call(metadata)
        metadata.raw_key
      end
    end
  end
end
