# frozen_string_literal: true

# When we idle all and move on but no more messages for a while, tick should kick in

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
    DT[:ticks] << true
  end
end

class Skipper < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor, :action

  def apply!(messages)
    if @once
      @action = :skip
    else
      @once = true
      @action = :seek
      @cursor = messages.first
      messages.clear
      DT[:done] = true
    end
  end

  def applied?
    true
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
  produce_many(DT.topic, DT.uuids(1)) unless DT.key?(:done)

  # This will hang if something is not working, so no assertions needed
  DT[:ticks].count >= 2
end
