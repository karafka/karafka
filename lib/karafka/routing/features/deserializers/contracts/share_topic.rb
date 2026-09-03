# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Deserializers < Base
        module Contracts
          # Share topics validate their deserializers exactly like consumer topics. Reuses the
          # consumer-group deserializers `Topic` contract.
          ShareTopic = Topic
        end
      end
    end
  end
end
