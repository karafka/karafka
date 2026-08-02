# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # Namespace holding the pause (backoff) routing configuration. There is no OSS pausing
      # feature to activate here - the backoff behavior is part of the topic itself and its
      # settings default to the global `config.pause.*`.
      module Pausing
      end
    end
  end
end
