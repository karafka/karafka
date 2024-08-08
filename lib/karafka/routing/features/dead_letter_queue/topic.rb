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
            max_retries: Default.new(DEFAULT_MAX_RETRIES),
            topic: Default.new(nil),
            independent: Default.new(false),
            transactional: Default.new(true),
            dispatch_method: Default.new(:produce_async),
            marking_method: Default.new(:mark_as_consumed)
          )
            @dead_letter_queue ||= Config.new(
              max_retries: max_retries,
              active: false,
              independent: independent,
              transactional: transactional,
              dispatch_method: dispatch_method,
              marking_method: marking_method
            )
            if Config.all_defaults?(topic, max_retries, independent, transactional, dispatch_method, marking_method)
              return @dead_letter_queue
            end

            @dead_letter_queue.active = !topic.is_a?(Default)
            @dead_letter_queue.topic = topic
            @dead_letter_queue.max_retries = max_retries
            @dead_letter_queue.independent = independent
            @dead_letter_queue.transactional = transactional
            @dead_letter_queue.dispatch_method = dispatch_method
            @dead_letter_queue.marking_method = marking_method
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
