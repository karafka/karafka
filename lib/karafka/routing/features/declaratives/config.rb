# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        # Backwards-compatible alias. The actual implementation has moved to
        # Karafka::Declaratives::Topic. This constant is preserved so that existing code
        # referencing Karafka::Routing::Features::Declaratives::Config continues to work.
        Config = Karafka::Declaratives::Topic
      end
    end
  end
end
