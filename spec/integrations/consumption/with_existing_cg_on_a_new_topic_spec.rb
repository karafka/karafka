# frozen_string_literal: true

# When we have an existing CG that gets a new topic from latest, it should pick from latest.
# We postpone second connection but because it has 'latest' start, it should not poll any data
# because data was published only in the past

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:topics] << topic.name
    mark_as_consumed!(messages.last)
    DT[:offset] = true
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  # This topic we will slow down by postponing the client connection
  topic DT.topics[1] do
    consumer Consumer
    initial_offset "latest"
  end
end

Karafka.monitor.subscribe("connection.listener.before_fetch_loop") do |event|
  next if event[:subscription_group].topics.map(&:name).include?(DT.topics[0])

  # Wait on the second SG until first topic stores offset
  sleep(0.1) until DT.key?(:offset)
end

produce_many(DT.topics[0], DT.uuids(100))
produce_many(DT.topics[1], DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(:offset) && sleep(5)
end

assert_equal 1, DT[:topics].uniq.size
