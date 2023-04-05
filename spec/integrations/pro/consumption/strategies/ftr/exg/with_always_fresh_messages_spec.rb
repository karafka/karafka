# frozen_string_literal: true

# When Karafka has expiring enabled but all the messages are fresh, nothing should be expired

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 1 minute
    expire_in(60_000)
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1))

  DT[0].count >= 50
end

previous = -1

# All should be present and all in order
DT[0].each do |offset|
  assert_equal previous + 1, offset

  previous = offset
end
