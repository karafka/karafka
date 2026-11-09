# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        # Declarative topics management for share-group topics. Reuses the consumer-group
        # {Features::ConsumerGroups::Declaratives} bridge, so share-group topics accept
        # `config(...)`, are managed by the `karafka topics` commands and are covered by the
        # strict declarative topics check the same way as consumer-group topics.
        class Declaratives < Base
        end
      end
    end
  end
end
