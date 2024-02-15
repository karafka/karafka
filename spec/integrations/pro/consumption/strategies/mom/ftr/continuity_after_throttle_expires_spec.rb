# frozen_string_literal: true

# When we throttle with MoM enabled and we process longer than the throttle, it should not have
# any impact on the processing order. It should also not mark offsets in any way.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 4
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    # Exceed throttle time
    sleep(0.6)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    throttling(limit: 2, interval: 500)
  end
end

Thread.new do
  loop do
    produce(DT.topic, '1', partition: 0)

    sleep(0.1)
  rescue StandardError
    nil
  end
end

start_karafka_and_wait_until do
  DT[:offsets].size >= 20
end

previous = -1

DT[:offsets].each do |offset|
  assert_equal previous + 1, offset

  previous = offset
end
