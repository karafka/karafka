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
    module Processing
      module Filters
        # Base for all the filters.
        # All filters (including custom) need to use this API.
        #
        # Due to the fact, that filters can limit data in such a way, that we need to pause or
        # seek (throttling for example), the api is not just "remove some things from batch" but
        # also provides ways to control the post-filtering operations that may be needed.
        class Base
          # @return [Karafka::Messages::Message, nil] the message that we want to use as a cursor
          #   one to pause or seek or nil if not applicable.
          attr_reader :cursor

          include Karafka::Core::Helpers::Time

          def initialize
            @applied = false
            @cursor = nil
          end

          # @param messages [Array<Karafka::Messages::Message>] array with messages. Please keep
          #   in mind, this may already be partial due to execution of previous filters.
          def apply!(messages)
            raise NotImplementedError, 'Implement in a subclass'
          end

          # @return [Symbol] filter post-execution action on consumer. Either `:skip`, `:pause` or
          #   `:seek`.
          def action
            :skip
          end

          # @return [Boolean] did this filter change messages in any way
          def applied?
            @applied
          end

          # @return [Integer] default timeout for pausing (if applicable)
          def timeout
            0
          end

          # @return [Boolean] should we use the cursor value to mark as consumed. If any of the
          #   filters returns true, we return lowers applicable cursor value (if any)
          def mark_as_consumed?
            false
          end

          # @return [Symbol] `:mark_as_consumed` or `:mark_as_consumed!`. Applicable only if
          #   marking is requested
          def marking_method
            :mark_as_consumed
          end
        end
      end
    end
  end
end
