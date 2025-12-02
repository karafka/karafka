# frozen_string_literal: true

module Karafka
  module Deserializing
    module Parallel
      # Handles injecting deserialized payloads back into Message objects
      # Separated from Future to maintain single responsibility
      module Injector
        class << self
          # Injects deserialized payloads into messages
          # Messages that failed during parallel deserialization are skipped (left untouched)
          # so lazy deserialization will retry them during consumption
          #
          # @param messages [Array<Karafka::Messages::Message>] messages to inject into
          # @param results [Array] deserialized results in same order as messages
          def call(messages, results)
            return if results.nil?

            messages.each_with_index do |message, idx|
              result = results[idx]

              # Skip errors - leave message untouched for lazy deserialization to retry
              next if result.equal?(DESERIALIZATION_ERROR)

              message.payload = result
            end
          end
        end
      end
    end
  end
end
