# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ConsumerGroups
        # Namespace holding the pause (backoff) routing configuration. There is no OSS pausing
        # feature to activate here - the backoff behavior is part of the consumer-group topic
        # itself ({Karafka::Routing::ConsumerGroups::Topic#pause}) and its settings default to the
        # global `config.pause.*`. Share groups (KIP-932) do not support pausing, so this is a
        # consumer-group only concern.
        module Pausing
        end
      end
    end
  end
end
