# frozen_string_literal: true

# Karafka should be able to consume same messages all the time in an endless loop
# This can be useful when doing development with a fixed data-set in kafka over which we don't
# have control (that is, cannot be changed)

setup_karafka do |config|
  # Not really needed as we seek back, but still just in case of a crash
  config.manual_offset_management = true
end

# The last one will act as an indicator that we're done
elements = Array.new(99) { SecureRandom.uuid } << '1'
elements.each { |data| produce(DT.topic, data) }

class Consumer < Karafka::BaseConsumer
  def consume
    # Process data only after the offset seek has been sent
    messages.each do |message|
      DT[0] << message.raw_payload

      # When we encounter last message out of those that we expected, let's rewind
      seek(20) if message.raw_payload == '1'
    end
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  # 100 initially and then a loop from 20th 4 times
  DT[0].size >= 420
end

# While we return there may be prefetched data that is still being processed before karafka stops
# so we cannot have a strict limitation here (async)
assert DT[0].size >= 420

# The last message should be consumed at least 5 times (first + min 4 loops)
assert DT[0].count { |val| val == '1' } >= 5

# First 20 messages should be consumed only once
elements[0..19].each do |payload|
  assert_equal 1, (DT[0].count { |val| val == payload })
end

# All other messages should be consumed at least 5 times
elements[20..-1].each do |payload|
  assert DT[0].count { |val| val == payload } >= 5
end

# Order of messages needs to be maintained within a single loop
previous = nil

DT[0].each do |payload|
  unless previous
    previous = payload
    next
  end

  # since the '1' is the one where we rewind, it will not match with previous
  assert_equal(elements.index(previous), elements.index(payload) - 1) unless previous == '1'

  previous = payload
end
