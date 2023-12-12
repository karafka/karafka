# frozen_string_literal: true

# When periodic gets an assignment it should tick in intervals despite never having any data

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    raise unless messages.empty?

    DT[:ticks] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

start_karafka_and_wait_until do
  DT[:ticks].count >= 5
end
