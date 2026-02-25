# frozen_string_literal: true

# Karafka should publish correct events post-initializing the consumer instances
# When initialization fails, it should also publish error

setup_karafka(allow_errors: %w[consumer.initialized.error])

class OkConsumer < Karafka::BaseConsumer
  def initialized
    DT[:ok] = true
  end

  def consume
  end
end

class NotOkConsumer < Karafka::BaseConsumer
  def initialized
    DT[:not_ok] = true

    raise
  end

  def consume
  end
end

Karafka::App.monitor.subscribe("consumer.initialize") do |event|
  DT[:pre] << event[:caller].class
end

Karafka::App.monitor.subscribe("consumer.initialized") do |event|
  DT[:post] << event[:caller].class
end

Karafka::App.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:type]
end

draw_routes do
  topic DT.topics[0] do
    consumer OkConsumer
  end

  topic DT.topics[1] do
    consumer NotOkConsumer
  end
end

produce(DT.topics[0], rand.to_s)
produce(DT.topics[1], rand.to_s)

start_karafka_and_wait_until do
  DT.key?(:ok) && DT.key?(:not_ok)
end

assert DT[:pre].include?(OkConsumer)
assert DT[:pre].include?(NotOkConsumer)
assert DT[:post].include?(OkConsumer)
assert !DT[:post].include?(NotOkConsumer)
assert_equal DT[:errors], %w[consumer.initialized.error]
