# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to use automatic cleaning to get rid of the payload
#
# We should fail when trying to deserialize a cleaned message

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each(clean: true) do |message|
      message.payload if (message.offset % 2).zero?

      DT[0] << true
    end

    # We should fail if we try to deserialize a cleaned message
    begin
      messages.first.payload
    rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
      DT[1] = true
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
