# frozen_string_literal: true

# We should be able to move the offset per partition using `:earliest` and `:latest`

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[partition] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer(Consumer)
    config(partitions: 2)
  end
end

10.times do
  produce(DT.topic, '', partition: 0)
  produce(DT.topic, '', partition: 1)
end

start_karafka_and_wait_until do
  DT[0].size >= 10 &&
    DT[1].size >= 10
end

Karafka::Admin.seek_consumer_group(
  DT.consumer_group,
  {
    DT.topic => {
      0 => :latest,
      1 => :earliest
    }
  }
)

offsets_with_lags = Karafka::Admin.read_lags_with_offsets[DT.consumer_group][DT.topic]

assert_equal 10, offsets_with_lags[0][:offset]
assert_equal 0, offsets_with_lags[0][:lag]

assert_equal 0, offsets_with_lags[1][:offset]
assert_equal 10, offsets_with_lags[1][:lag]
