# frozen_string_literal: true

# We should be able to mix moving of the same topic data and use different type of location
# in between partitions.

setup_karafka

draw_routes do
  topic DT.topic do
    consumer Karafka::BaseConsumer
    config(partitions: 2)
  end
end

time_ref = nil

10.times do |i|
  time_ref = Time.now if i == 4
  sleep(0.1)
  produce(DT.topic, '', partition: 0)
  produce(DT.topic, '', partition: 1)
end

Karafka::Admin.seek_consumer_group(
  DT.consumer_group,
  {
    DT.topic => {
      0 => time_ref,
      1 => 1
    }
  }
)

results = Karafka::Admin.read_lags_with_offsets
cg = DT.consumer_group
part_results = results.fetch(cg)

assert_equal 4, part_results[DT.topic][0][:offset]
assert_equal 1, part_results[DT.topic][1][:offset]
