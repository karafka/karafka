# frozen_string_literal: true

# Seeking beyond high watermark should trigger reset back to earliest

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:runs] << messages.first.offset

    seek(21)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:runs].size >= 5
end

assert_equal [0], DT[:runs].uniq
