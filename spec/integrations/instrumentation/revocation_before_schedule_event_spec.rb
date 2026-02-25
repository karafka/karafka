# frozen_string_literal: true

# Karafka should trigger proper before schedule event for revocation

setup_karafka

DT[:revoked] = []
DT[:pre] = Set.new
DT[:post] = Set.new

Karafka::App.monitor.subscribe("consumer.before_schedule_revoked") do
  DT[:revoked] << Time.now.to_f
end

class Consumer < Karafka::BaseConsumer
  def consume
    if DT[:revoked].empty?
      DT[:pre_states] << Karafka::App.assignments
      DT[:pre] << messages.metadata.partition
    else
      DT[:post_states] << Karafka::App.assignments
      DT[:post] << messages.metadata.partition
    end
  end

  def revoked
    DT[:revoked] << { messages.metadata.partition => Time.now }
  end
end

draw_routes do
  consumer_group DT.topic do
    topic DT.topic do
      config(partitions: 3)
      consumer Consumer
      manual_offset_management true
    end
  end
end

elements = DT.uuids(100)
elements.each { |data| produce(DT.topic, data, partition: rand(0..2)) }

consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)
  consumer.poll(100) while DT[:end].empty?

  sleep(2)
end

start_karafka_and_wait_until do
  if DT[:post].empty?
    false
  else
    sleep 2
    true
  end
end

DT[:end] << true

assert DT.key?(:revoked)

other.join
consumer.close

last_pre = DT[:pre_states].last.values.last
last_post = DT[:post_states].last.values.last

# post revocation should not report on lost partitions
assert last_pre.size > last_post.size
