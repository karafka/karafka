# frozen_string_literal: true

# Seeking to the high watermark offset should not reset the consumer offset position

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:runs] << true

    seek(20)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT.key?(:runs) && sleep(3)
end

assert_equal DT[:runs].size, 1
