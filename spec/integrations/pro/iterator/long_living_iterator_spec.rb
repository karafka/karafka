# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should have a way to create long living iterators that wait for messages

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

Thread.new do
  loop do
    produce(DT.topic, '1')

    sleep(0.02)
  rescue StandardError
    nil
  end
end

iterator = Karafka::Pro::Iterator.new(
  { DT.topic => -1 },
  settings: { 'enable.partition.eof': false },
  yield_nil: true
)

# Stop iterator when 100 messages are accumulated
limit = 100
buffer = []

iterator.each do |message|
  break if buffer.count >= limit

  # Message may be a nil when `yield_nil` is set to true
  buffer << message if message
end

assert_equal buffer.size, 100
