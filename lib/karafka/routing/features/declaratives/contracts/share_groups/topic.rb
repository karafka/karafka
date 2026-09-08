# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        module Contracts
          # Namespace for this feature's share-group routing hooks.
          module ShareGroups
            # Share topics validate their declarative structure exactly like consumer topics.
            # Reuses the consumer-group declaratives `Topic` contract.
            Topic = ConsumerGroups::Topic
          end
        end
      end
    end
  end
end
