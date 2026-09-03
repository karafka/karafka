# frozen_string_literal: true

module Karafka
  module Routing
    module Groups
      # Namespaced alias for the canonical {Karafka::Routing::ConsumerGroup}. Provided so the
      # `Groups::ConsumerGroup` / `Groups::ShareGroup` pair reads symmetrically (see issue #3130),
      # while keeping the flat `Routing::ConsumerGroup` constant that is widely referenced.
      ConsumerGroup = Karafka::Routing::ConsumerGroup
    end
  end
end
