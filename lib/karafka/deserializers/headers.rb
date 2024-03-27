# frozen_string_literal: true

module Karafka
  module Deserializers
    # Default message headers deserializer
    class Headers
      # @param metadata [Karafka::Messages::Metadata] metadata object from which we obtain the
      #   `#raw_headers`
      # @return [Hash] expected message headers hash
      def call(metadata)
        metadata.raw_headers
      end
    end
  end
end
