# frozen_string_literal: true

# Karafka should be able to exit from iterator even if no more messages are being shipped

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

produce(DT.topic, '1')

iterator = Karafka::Pro::Iterator.new(
  { DT.topic => -1 },
  settings: { 'enable.partition.eof': false },
  yield_nil: true
)

# Stop if there were no messages for longer than 5 seconds
last_timestamp = Time.now
iterator.each do |message|
  last_timestamp = message.timestamp if message

  break if (Time.now - last_timestamp) >= 5
end

assert (Time.now - last_timestamp) >= 5
