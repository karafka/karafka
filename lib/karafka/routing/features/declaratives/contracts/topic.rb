# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        # This feature validation contracts
        module Contracts
          # Backwards-compatible alias. The actual contract has moved to
          # Karafka::Declaratives::Contracts::Topic. This constant is preserved so that existing
          # code referencing the old location continues to work, and so the routing feature
          # Expander mechanism continues to find and apply the contract.
          Topic = Karafka::Declaratives::Contracts::Topic
        end
      end
    end
  end
end
