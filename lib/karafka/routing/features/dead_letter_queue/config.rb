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
          keyword_init: true
        ) { alias_method :active?, :active }
      end
    end
  end
end
