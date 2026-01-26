# frozen_string_literal: true

# We should be able to move the offset to requested location per topic partition

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT["#{topic.name}-#{partition}"] << message.offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    config(partitions: 3)
  end

  topic DT.topics[1] do
    consumer Consumer
    config(partitions: 3)
  end
end

10.times do
  3.times do |partition|
    produce(DT.topics[0], "", partition: partition)
    produce(DT.topics[1], "", partition: partition)
  end
end

start_karafka_and_wait_until do
  DT["#{DT.topics[0]}-0"].size >= 10 &&
    DT["#{DT.topics[0]}-1"].size >= 10 &&
    DT["#{DT.topics[0]}-2"].size >= 10 &&
    DT["#{DT.topics[1]}-0"].size >= 10 &&
    DT["#{DT.topics[1]}-1"].size >= 10 &&
    DT["#{DT.topics[1]}-2"].size >= 10
end

Karafka::Admin.seek_consumer_group(
  DT.consumer_group,
  {
    DT.topics[0] => {
      0 => 1,
      1 => 2,
      2 => 3
    },
    DT.topics[1] => {
      0 => 4,
      1 => 5,
      2 => 6
    }
  }
)

results = Karafka::Admin.read_lags_with_offsets
cg = DT.consumer_group
part_results = results.fetch(cg)

assert_equal 1, part_results[DT.topics[0]][0][:offset]
assert_equal 2, part_results[DT.topics[0]][1][:offset]
assert_equal 3, part_results[DT.topics[0]][2][:offset]
assert_equal 4, part_results[DT.topics[1]][0][:offset]
assert_equal 5, part_results[DT.topics[1]][1][:offset]
assert_equal 6, part_results[DT.topics[1]][2][:offset]
