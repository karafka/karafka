# frozen_string_literal: true

# We should be able to move the offset to where we want on one partition directly by the time
# reference instead of an offset

setup_karafka

draw_routes(Karafka::BaseConsumer)

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
