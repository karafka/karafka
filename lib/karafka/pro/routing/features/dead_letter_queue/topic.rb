# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
