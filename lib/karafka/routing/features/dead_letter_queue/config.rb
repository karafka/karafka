# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class DeadLetterQueue < Base
        # Config for dead letter queue feature
        Config = Struct.new(
          :active,
          # We add skip variants but in regular we support only `:one`
          :max_retries,
          # To what topic the skipped messages should be moved
          :topic,
          # Should retries be handled collectively on a batch or independently per message
          :independent,
          # Move to DLQ and mark as consumed in transactional mode (if applicable)
          :transactional,
          keyword_init: true
        ) do
          alias_method :active?, :active
          alias_method :independent?, :independent
          alias_method :transactional?, :transactional
        end
      end
    end
  end
end
