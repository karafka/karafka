# frozen_string_literal: true

# When we idle all the time on incoming data, we should never tick
# It is end user FTR makes this decision to skip

class Listener
  def on_filtering_seek(_)
    DT[:seeks] << true
  end
end

setup_karafka do |config|
  config.max_messages = 10
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end

  # Should never tick because of constant ftr
  def tick
    raise
  end
end

class Skipper
  attr_reader :cursor

  def apply!(messages)
    @cursor = messages.first
    messages.clear
  end

  def applied?
    true
  end

  def action
    :seek
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { Skipper.new }
    periodic true
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1))

  DT[:seeks].count >= 50
end
