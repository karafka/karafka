# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When Karafka has expiring enabled and expiring is super short, we should never get any messages

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 1 ms
    expire_in(1)
  end
end

dispatched = []

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1))
  dispatched << 1

  dispatched.count >= 50
end

assert DT[0].empty?
