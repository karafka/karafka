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
          # @return [Config] defined config
          def dead_letter_queue(
            max_retries: Undefined,
            topic: Undefined,
            independent: Undefined,
            transactional: Undefined,
            dispatch_method: Undefined,
            marking_method: Undefined
          )
            @dead_letter_queue ||= Config.new(
              max_retries: DEFAULT_MAX_RETRIES,
              active: false,
              independent: false,
              transactional: true,
              dispatch_method: :produce_async,
              marking_method: :mark_as_consumed
            )
            if [topic, max_retries, independent, transactional, dispatch_method, marking_method].uniq == [Undefined]
              return @dead_letter_queue
            end

            @dead_letter_queue.active = topic != Undefined
            @dead_letter_queue.max_retries = max_retries unless max_retries == Undefined
            @dead_letter_queue.independent = independent unless independent == Undefined
            @dead_letter_queue.transactional = transactional unless transactional == Undefined
            @dead_letter_queue.dispatch_method = dispatch_method unless dispatch_method == Undefined
            @dead_letter_queue.marking_method = marking_method unless marking_method == Undefined
            @dead_letter_queue
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
