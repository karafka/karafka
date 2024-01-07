# frozen_string_literal: true

# Karafka should emit event each time there is a join timeout on running listeners

setup_karafka do |config|
  config.internal.join_timeout = 1_000
end

Consumer = Class.new(Karafka::BaseConsumer)

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

class Listener
  def on_runner_join_timeout(event)
    DT[:events] << [event, Time.now.to_f]
  end
end

Karafka::App.monitor.subscribe(Listener.new)

start_karafka_and_wait_until do
  DT[:events].size >= 5
end

previous = nil

DT[:events].each do |event|
  unless previous
    previous = event

    next
  end

  assert !event.first[:listeners].nil?

  # There should be a distance in between each of them equal to join timeout
  assert event.last - previous.last >= 1

  previous = event
end
