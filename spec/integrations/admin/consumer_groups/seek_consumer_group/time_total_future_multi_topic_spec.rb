# frozen_string_literal: true

# Seeking multiple topics to a future timestamp should move all partitions to the HWM.
# This exercises the batch list_offsets admin call that replaces the per-partition
# query_watermark_offsets fallback when offsets_for_times returns a negative offset.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT["#{topic.name}-#{partition}"] << message.offset
    end
  end
end

draw_topics do
  topic DT.topics[0] do
    partitions 2
  end

  topic DT.topics[1] do
    partitions 2
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

10.times do
  2.times do |partition|
    produce(DT.topics[0], "", partition: partition)
    produce(DT.topics[1], "", partition: partition)
  end
end

start_karafka_and_wait_until do
  DT["#{DT.topics[0]}-0"].size >= 10 &&
    DT["#{DT.topics[0]}-1"].size >= 10 &&
    DT["#{DT.topics[1]}-0"].size >= 10 &&
    DT["#{DT.topics[1]}-1"].size >= 10
end

# Future timestamp triggers HWM fallback for all 4 partitions across 2 topics.
# Previously this made 4 sequential query_watermark_offsets calls; now a single batch
# list_offsets call covers all of them.
Karafka::Admin.seek_consumer_group(
  DT.group,
  {
    DT.topics[0] => Time.now + (60 * 60),
    DT.topics[1] => Time.now + (60 * 60)
  }
)

results = Karafka::Admin.read_lags_with_offsets
cg = DT.group
part_results = results.fetch(cg)

assert_equal 10, part_results[DT.topics[0]][0][:offset]
assert_equal 10, part_results[DT.topics[0]][1][:offset]
assert_equal 10, part_results[DT.topics[1]][0][:offset]
assert_equal 10, part_results[DT.topics[1]][1][:offset]
