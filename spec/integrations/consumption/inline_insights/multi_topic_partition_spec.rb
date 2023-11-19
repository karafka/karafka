# frozen_string_literal: true

# Inline Insights should ship correct partition and topic details and not mix them

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT["#{topic.name}-#{partition}"] << insights
  end
end

draw_routes do
  topic DT.topics[0] do
    config(partitions: 2)
    consumer Consumer
    inline_insights(true)
  end

  topic DT.topics[1] do
    config(partitions: 2)
    consumer Consumer
    inline_insights(true)
  end
end

[
  DT.topics[0],
  DT.topics[1]
].each do |topic|
  2.times do |partition|
    elements = DT.uuids(10)
    produce_many(topic, elements, partition: partition)
  end
end

start_karafka_and_wait_until do
  DT.data.size >= 4 && DT.data.all? { |sub| !sub.last.empty? }
end

DT.data.each do |key, values|
  _topic, partition = key.split('-')

  assert_equal partition.to_i, values.last['partition']
end
