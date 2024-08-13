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
          # Strategy to apply (if strategies supported)
          :strategy,
          # Should we use `#produce_sync` or `#produce_async`
          :dispatch_method,
          # Should we use `#mark_as_consumed` or `#mark_as_consumed!` (in flows that mark)
          :marking_method,
          # Should we mark as consumed after dispatch or not. True for most cases, except MOM where
          # it is on user to decide (false by default)
          :mark_after_dispatch,
          # Initialize with kwargs
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
