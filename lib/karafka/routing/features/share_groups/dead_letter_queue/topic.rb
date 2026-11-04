# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        class DeadLetterQueue < Base
          # DLQ topic extensions
          module Topic
            # After how many retries should data be moved to DLQ
            DEFAULT_MAX_RETRIES = 3

            private_constant :DEFAULT_MAX_RETRIES

            # This method sets up the extra instance variable to nil before calling
            # the parent class initializer. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              @dead_letter_queue = nil
              super
            end

            # @param max_retries [Integer] after how many retries (redeliveries) should we move a
            #   failing record to the dlq. It needs to be lower than the share group
            #   `share.delivery.count.limit` (5 by default), as the broker drops records that
            #   reach that limit.
            # @param topic [String, false] where the records should be moved if failing or false
            #   if we do not want to move them anywhere and just reject them
            # @param dispatch_method [Symbol] `:produce_async` or `:produce_sync`. Describes
            #   whether dispatch on dlq should be sync or async (async by default)
            # @return [Config] defined config
            def dead_letter_queue(
              max_retries: DEFAULT_MAX_RETRIES,
              topic: nil,
              dispatch_method: :produce_async
            )
              @dead_letter_queue ||= Config.new(
                active: !topic.nil?,
                max_retries: max_retries,
                topic: topic,
                dispatch_method: dispatch_method
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
end
