# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        # Contracts used by the routing Expander to validate topic declarations after draw
        module Contracts
          # Delegates to the canonical contract in the Declaratives namespace.
          # Required here because the Expander looks up `scope::Contracts::Topic`.
          Topic = Karafka::Declaratives::Contracts::Topic
        end
      end
    end
  end
end
