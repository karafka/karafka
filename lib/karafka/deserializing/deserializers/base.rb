# frozen_string_literal: true

module Karafka
  module Deserializing
    module Deserializers
      # Base class for all default deserializers
      # Frozen on initialization for Ractor shareability
      class Base
        def initialize
          freeze
        end
      end
    end
  end
end
