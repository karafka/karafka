# frozen_string_literal: true

# We should be able to move the the earliest offset by providing :earliest as the seek value on
# the topic level

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes(Consumer)

10.times do
  sleep(0.1)
  produce(DT.topic, '')
end

start_karafka_and_wait_until do
  DT[0].size >= 10
end

Karafka::Admin.seek_consumer_group(
  DT.consumer_group,
  { DT.topic => :earliest }
)

assert_equal 0, fetch_next_offset
