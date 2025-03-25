# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to chain filters and to achieve expected processing flow
# In this scenario we will filter all odd offsets and we will make sure, we process data with
# a delay and with throttling used to make sure we do not process more than 5 messages per second
# It is important to notice, that the order of filters is important. If we throttle before we
# filter, we will actually always process late because throttling will occur on odd and even.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:counts] << messages.size
    DT[:times] << Time.now

    messages.each do |message|
      DT[:offsets] << message.offset
    end
  end
end

class OddRemoval < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil

    messages.delete_if do |message|
      !(message.offset % 2).zero?
    end
  end

  def action
    :skip
  end

  def applied?
    true
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    filter(->(*) { OddRemoval.new })
    throttle(limit: 5, interval: 1_000)
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(5))

  DT[:offsets].size > 50
end

# All offsets that we've processed should be even and in order
previous = -2

DT[:offsets].each do |offset|
  assert_equal previous + 2, offset
  previous = offset
end

# We should never have more than 5 messages in a batch
assert(DT[:counts].all? { |count| count <= 5 })

# There should always be a delay on average in between batches
time_taken = DT[:times].last - DT[:times].first
average = (time_taken / DT[:counts].sum)
assert average >= 0.17, average

# On average will will get 1,4,1,4,1,4 because of throttling, but since throttling is applied
# after filtering, we should always be above 2 with the number
assert (DT[:counts].sum / DT[:counts].size.to_f) > 2
