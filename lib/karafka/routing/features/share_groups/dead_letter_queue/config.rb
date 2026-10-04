# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        class DeadLetterQueue < Base
          # Config for dead letter queue feature
          Config = Struct.new(
            :active,
            # After how many retries (redeliveries) a failing record should be moved
            :max_retries,
            # To what topic the failing records should be moved (false to only reject them)
            :topic,
            # Should we use `#produce_sync` or `#produce_async`
            :dispatch_method,
            # Initialize with kwargs
            keyword_init: true
          ) do
            alias_method :active?, :active
          end
        end
      end
    end
  end
end
