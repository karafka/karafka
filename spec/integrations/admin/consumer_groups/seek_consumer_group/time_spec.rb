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

time_ref = nil

10.times do |i|
  time_ref = Time.now if i == 4
  sleep(0.1)
  produce(DT.topic, '')
end

Karafka::Admin.seek_consumer_group(
  DT.consumer_group,
  { DT.topic => { 0 => time_ref } }
)

assert_equal 4, fetch_next_offset
