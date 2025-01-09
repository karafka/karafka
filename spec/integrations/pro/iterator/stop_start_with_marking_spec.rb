# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able with proper settings

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

produce_many(DT.topic, DT.uuids(50))

topics = { DT.topic => { 0 => true } }

settings = {
  # Setup a custom group that you want to use for offset storage
  'group.id': SecureRandom.uuid,
  # Start from beginning if needed
  'auto.offset.reset': 'beginning'
}

iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

count = 0
iterator.each do |message|
  count += 1

  DT[message.partition] << message.offset
  iterator.mark_as_consumed(message)

  iterator.stop if count >= 10
end

iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

count = 0
iterator.each do |message|
  count += 1

  DT[message.partition] << message.offset
  iterator.mark_as_consumed!(message)

  iterator.stop if count >= 10
end

iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

count = 0
iterator.each do |message|
  count += 1

  DT[message.partition] << message.offset
  iterator.mark_as_consumed!(message)

  iterator.stop if count >= 10
end

assert_equal DT[0], (0..29).to_a
