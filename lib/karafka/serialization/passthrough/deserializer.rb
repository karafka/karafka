# frozen_string_literal: true

module Karafka
  module Serialization
    # Namespace for passthrough deserializers that only return the initial data
    module Passthrough
      # Deserializer that takes data and returns it the same. Used when our expectation is to get
      # the data in an unchanged format.
      class Deserializer
        # Returns data in an unchanged format.
        #
        # @param data [Object]
        # @return [Object]
        def call(data)
          data
        end
      end
    end
  end
end
