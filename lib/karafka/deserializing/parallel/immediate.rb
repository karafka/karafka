# frozen_string_literal: true

module Karafka
  module Deserializing
    module Parallel
      # Immediate (no-op) deserialization result for a batch the pool did not dispatch (pool not
      # started or batch below `min_payloads`)
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
