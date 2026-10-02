# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ConsumerGroups
        # Namespace holding the pause (backoff) routing configuration. There is no OSS pausing
        # feature to activate here - the backoff behavior is part of the consumer-group topic
        # itself ({Karafka::Routing::ConsumerGroups::Topic#pause}) and its settings default to the
        # global `config.pause.*`. Share groups mirror this under
        # {Features::ShareGroups::Pausing}, following the per-mode duplication convention.
        module Pausing
        end
      end
    end
  end
end
