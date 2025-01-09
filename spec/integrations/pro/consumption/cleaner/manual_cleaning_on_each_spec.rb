# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to iterate over messages and run cleaning both with and without prior
# deserialization in a manual mode
#
# We should fail when trying to deserialize a cleaned message

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message.payload if (message.offset % 2).zero?

      message.clean!

      # We should fail if we try to deserialize a cleaned message
      if message.offset == 5
        begin
          message.payload
        rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
          DT[1] = true
        end

        begin
          message.key
        rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
          DT[2] = true
        end

        begin
          message.headers
        rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
          DT[3] = true
        end
      end

      DT[0] << true
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(100).map { |val| { val: val }.to_json }
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert DT.key?(1)
assert DT.key?(2)
assert DT.key?(3)
