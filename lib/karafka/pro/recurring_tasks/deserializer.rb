# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Recurring Tasks data deserializer. We compress data ourselves because we cannot rely on
      # any external optional features like certain compression types, etc. By doing this that way
      # we can ensure we have full control over the compression.
      #
      # @note We use `symbolize_names` because we want to use the same convention of hash building
      #   for producing, consuming and displaying related data as in other places.
      class Deserializer
        # @param message [::Karafka::Messages::Message]
        # @return [Hash] deserialized data
        def call(message)
          ::JSON.parse(
            Zlib::Inflate.inflate(message.raw_payload),
            symbolize_names: true
          )
        end
      end
    end
  end
end
