# frozen_string_literal: true

# Karafka should allow to use the framework event bus for internal events as long as those are
# registered.

setup_karafka

Karafka.monitor.notifications_bus.register_event("app.custom.event")

# via block
Karafka.monitor.subscribe("app.custom.event") do |event|
  DT[:block_sub] = event
end

class AppListener
  def on_app_custom_event(event)
    DT[:list_sub] = event
  end
end

# via listener
Karafka.monitor.subscribe(AppListener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    Karafka.monitor.instrument("app.custom.event") do
      sleep(0.2)
      DT[0] << true
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce(DT.topic, rand.to_s)

start_karafka_and_wait_until do
  DT.key?(0) && DT.key?(:block_sub) && DT.key?(:list_sub)
end

assert_equal DT[:block_sub][:time], DT[:list_sub][:time]
assert DT[:block_sub][:time] >= 200
