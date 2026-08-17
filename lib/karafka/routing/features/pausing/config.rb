# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module Pausing
        # Per-topic pause (backoff) configuration value object.
        #
        # Defaults to the global `config.pause.*` settings unless overridden on a per-topic basis.
        #
        # Unlike most feature configs, `active` here does not switch the behavior on or off - the
        # pause/backoff always applies. It only marks whether these settings were explicitly set
        # for this topic (`true`) or inherited from the global defaults (`false`).
        Config = Struct.new(
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
end
