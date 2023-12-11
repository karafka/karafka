# frozen_string_literal: true

# If we try to tick on a non-existing topic, we should not.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    raise
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

start_karafka_and_wait_until do
  sleep(10)
end
