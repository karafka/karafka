# frozen_string_literal: true

# Karafka should pause and if pausing spans across batches, it should work and wait

setup_karafka(allow_errors: true) do |config|
  # 60 seconds, long enough for it to not restart upon us finishing
  config.pause_timeout = 60 * 1_000
  config.pause_max_timeout = 60 * 1_000
  config.max_messages = 1
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[0] << object_id
    end

    raise StandardError
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[1] << object_id
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topics.first do
      consumer Consumer1
    end

    topic DT.topics.last do
      consumer Consumer2
    end
  end
end

elements = DT.uuids(5)

elements.each do |data|
  produce(DT.topics.first, data)
  produce(DT.topics.last, data)
end

start_karafka_and_wait_until do
  DT[0].size >= 1 &&
    DT[1].size >= 5
end

assert_equal 1, DT[0].size
assert_equal 5, DT[1].size
assert_equal 1, DT[1].uniq.size
