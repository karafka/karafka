# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        # Namespace holding the pause (backoff) routing configuration for share groups. Mirrors
        # the consumer-group {Features::ConsumerGroups::Pausing} - there is no feature to activate
        # here, the backoff behavior is part of the share-group topic itself
        # ({Karafka::Routing::ShareGroups::Topic#pause}) and its settings default to the global
        # `config.pause.*`.
        module Pausing
        end
      end
    end
  end
end
