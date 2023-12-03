# frozen_string_literal: true

# We should be able to move the offset way beyond in time and should just select first offset

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
  { DT.topic => { 0 => Time.now - 60 * 60 } }
)

assert_equal 0, fetch_first_offset
