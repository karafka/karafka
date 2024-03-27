# frozen_string_literal: true

module Karafka
  module Deserializers
    # Default message key deserializer
    class Key
      # @param metadata [Karafka::Messages::Metadata] metadata object from which we obtain the
      #   `#raw_key`
      # @return [String] expected message key in a string format
      def call(metadata)
        metadata.raw_key
      end
    end
  end
end
