# frozen_string_literal: true

module Karafka
  module Routing
    class Topic
      # Per-topic pause (backoff) configuration value object.
      #
      # In OSS this always mirrors the global `config.pause.*` settings, since overriding pausing on
      # a per-topic basis is a Karafka Pro feature (Granular Backoffs). Pro's Pausing feature
      # overrides `Topic#pause` to allow per-topic overrides while returning this same value object.
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
