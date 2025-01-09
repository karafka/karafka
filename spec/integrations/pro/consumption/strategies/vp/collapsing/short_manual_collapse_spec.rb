# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When Karafka collapses for a short time we should regain ability to process in VPs

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    collapse_until!(50)

    messages.each do |message|
      DT[0] << [message.offset, collapsed?]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100
end

# In theory all up until 50 + 9 (batch edge case) and first could operate in collapse and we check
# that after that VPs are restored

assert_equal false, DT[0].first.last

DT[0].each do |sample|
  next if sample.first < 60

  assert_equal false, sample.last
end
