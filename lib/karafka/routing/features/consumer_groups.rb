# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Consumer-group-specific routing features. A parallel `ShareGroups` namespace will hold
      # share-group-specific feature implementations once KIP-932 lands.
      module ConsumerGroups
      end
    end
  end
end
