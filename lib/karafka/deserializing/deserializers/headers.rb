# frozen_string_literal: true

module Karafka
  # Namespace for all deserialization-related components
  # This includes both the default deserializers and parallel deserialization infrastructure
  module Deserializing
    # Module for all supported by default deserializers
    module Deserializers
      # Default message headers deserializer
      class Headers < Base
        # @param metadata [Karafka::Messages::Metadata] metadata object from which we obtain the
        #   `#raw_headers`
        # @return [Hash] expected message headers hash
        def call(metadata)
          metadata.raw_headers
        end
      end
    end
  end
end
