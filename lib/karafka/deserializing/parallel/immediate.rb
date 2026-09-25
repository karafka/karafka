# frozen_string_literal: true

module Karafka
  module Deserializing
    module Parallel
      # Immediate (no-op) deserialization result for when parallel deserialization
      # didn't happen (thresholds not met, feature disabled, etc.)
      # Allows code to always call .retrieve without nil checks
      class Immediate
        # Singleton instance for efficiency
        INSTANCE = new.freeze

        # @return [Immediate] the singleton instance
        def self.instance
          INSTANCE
        end

        # @return [nil] always nil since no parallel deserialization happened
        # Lazy deserialization will handle it when payload is accessed
        def retrieve
          nil
        end
      end
    end
  end
end
