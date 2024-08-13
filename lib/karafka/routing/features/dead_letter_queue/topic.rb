# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class DeadLetterQueue < Base
        # DLQ topic extensions
        module Topic
          # After how many retries should be move data to DLQ
          DEFAULT_MAX_RETRIES = 3

          private_constant :DEFAULT_MAX_RETRIES

          # @param max_retries [Integer] after how many retries should we move data to dlq
          # @param topic [String, false] where the messages should be moved if failing or false
          #   if we do not want to move it anywhere and just skip
          # @param independent [Boolean] needs to be true in order for each marking as consumed
          #   in a retry flow to reset the errors counter
          # @param transactional [Boolean] if applicable, should transaction be used to move
          #   given message to the dead-letter topic and mark it as consumed.
          # @param dispatch_method [Symbol] `:produce_async` or `:produce_sync`. Describes
          #   whether dispatch on dlq should be sync or async (async by default)
          # @param marking_method [Symbol] `:mark_as_consumed` or `:mark_as_consumed!`. Describes
          #   whether marking on DLQ should be async or sync (async by default)
          # @param mark_after_dispatch [Boolean, nil] Should we mark after dispatch. `nil` means
          #   that the default strategy approach to marking will be used. `true` or `false`
          #   overwrites the default
          # @return [Config] defined config
          def dead_letter_queue(
            max_retries: DEFAULT_MAX_RETRIES,
            topic: nil,
            independent: false,
            transactional: true,
            dispatch_method: :produce_async,
            marking_method: :mark_as_consumed,
            mark_after_dispatch: nil
          )
            @dead_letter_queue ||= Config.new(
              active: !topic.nil?,
              max_retries: max_retries,
              topic: topic,
              independent: independent,
              transactional: transactional,
              dispatch_method: dispatch_method,
              marking_method: marking_method,
              mark_after_dispatch: mark_after_dispatch
            )
          end

          # @return [Boolean] is the dlq active or not
          def dead_letter_queue?
            dead_letter_queue.active?
          end

          # @return [Hash] topic with all its native configuration options plus dlq settings
          def to_h
            super.merge(
              dead_letter_queue: dead_letter_queue.to_h
            ).freeze
          end
        end
      end
    end
  end
end
