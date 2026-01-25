# frozen_string_literal: true

# We should be able to move the offset to where we want on one partition directly by the time
# reference instead of an offset

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
  produce(DT.topic, "")
end

start_karafka_and_wait_until do
  DT[0].size >= 10
end

Karafka::Admin.seek_consumer_group(
  DT.consumer_group,
  { DT.topic => { 0 => Time.now + (60 * 60) } }
)

assert_equal 10, fetch_next_offset
