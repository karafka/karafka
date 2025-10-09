# frozen_string_literal: true

# Karafka should instrument prior to each consumer being scheduled

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(Consumer)

elements = DT.uuids(10)
produce_many(DT.topic, elements)

Karafka::App.monitor.subscribe('consumer.before_schedule_consume') do |event|
  DT[:events] << event[:caller]
  DT[:consumes] << Time.now.to_f
end

Karafka::App.monitor.subscribe('consumer.before_schedule_shutdown') do
  DT[:shutdown] << Time.now.to_f
end

start_karafka_and_wait_until do
  DT[:events].size >= 10
end

assert(DT[:events].all?(Consumer))

# shutdown enqueue should happen after all work is done
assert DT[:consumes].last < DT[:shutdown].last
