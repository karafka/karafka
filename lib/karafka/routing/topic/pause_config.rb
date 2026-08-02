# frozen_string_literal: true

module Karafka
  module Routing
    class Topic
      # Per-topic pause (backoff) configuration value object.
      #
      # Defaults to the global `config.pause.*` settings unless overridden on a per-topic basis.
      PauseConfig = Struct.new(
        :active,
        :timeout,
        :max_timeout,
        :with_exponential_backoff,
        keyword_init: true
      ) do
        alias_method :active?, :active
        alias_method :with_exponential_backoff?, :with_exponential_backoff
      end
    end
  end
end
