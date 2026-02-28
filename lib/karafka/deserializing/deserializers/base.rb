# frozen_string_literal: true

module Karafka
  module Deserializing
    module Deserializers
      # Base class for all default deserializers
      # Automatically freezes instances to make them Ractor-shareable
      # for parallel deserialization support
      class Base
        def initialize
          freeze
        end
      end
    end
  end
end
