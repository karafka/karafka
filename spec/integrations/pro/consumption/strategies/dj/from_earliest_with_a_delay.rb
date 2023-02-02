# frozen_string_literal: true

# Karafka should be able to

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [Time.now.to_f - message.timestamp.to_f, message.offset]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 5 seconds
    delayed_job(delay_for: 5_000)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal elements, DT[0]
assert_equal 1, DT.data.size
