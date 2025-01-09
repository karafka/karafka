# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class DeadLetterQueue < Base
          # Expansions to the topic API in DLQ
          module Topic
            # @param strategy [#call, nil] Strategy we want to use or nil if a default strategy
            # (same as in OSS) should be applied
            # @param args [Hash] OSS DLQ arguments
            def dead_letter_queue(strategy: nil, **args)
              return @dead_letter_queue if @dead_letter_queue

              super(**args).tap do |config|
                # If explicit strategy is not provided, use the default approach from OSS
                config.strategy = strategy || lambda do |_errors_tracker, attempt|
                  attempt > config.max_retries ? :dispatch : :retry
                end
              end
            end
          end
        end
      end
    end
  end
end
