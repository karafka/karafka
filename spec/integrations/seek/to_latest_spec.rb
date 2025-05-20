# frozen_string_literal: true

# If we seek to the latest, we should start from the high watermark

setup_karafka do |config|
  config.initial_offset = 'earliest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    if @after_seek
      messages.each do |message|
        DT[message.metadata.partition] << message.raw_payload
      end
    else
      DT[:seek] = true
      seek(:latest)
      @after_seek = true
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(20)

Thread.new do
  sleep(5)

  produce_many(DT.topic, elements)

  sleep(0.1) until DT.key?(:seek)
  sleep(5)

  produce_many(DT.topic, %w[test])
end

start_karafka_and_wait_until do
  DT[0].include?('test')
end

assert_equal DT[0].last, 'test'
