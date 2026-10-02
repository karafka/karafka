# frozen_string_literal: true

# Share group (KIP-932) consumers should publish the consumer lifecycle events with the share
# consumer as the caller: initialize/initialized (with an error when initialization fails),
# before_schedule_consume, consume/consumed (one per job) and shutting_down/shutdown.

setup_karafka(allow_errors: %w[consumer.initialized.error])

class OkConsumer < Karafka::ShareConsumer
  def initialized
    DT[:ok] = true
  end

  def consume
    DT[:batches] << messages.size

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

class NotOkConsumer < Karafka::ShareConsumer
  def initialized
    DT[:not_ok] = true

    raise
  end

  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

%w[
  consumer.initialize
  consumer.initialized
  consumer.before_schedule_consume
  consumer.consume
  consumer.consumed
  consumer.before_schedule_shutdown
  consumer.shutting_down
  consumer.shutdown
].each do |event_name|
  Karafka::App.monitor.subscribe(event_name) do |event|
    DT[event_name] << event[:caller]
  end
end

Karafka::App.monitor.subscribe("consumer.consume") do |event|
  DT[:consume_sizes] << event[:caller].messages.size if event[:caller].is_a?(OkConsumer)
end

Karafka::App.monitor.subscribe("consumer.consumed") do |event|
  DT[:consumed_sizes] << event[:caller].messages.size if event[:caller].is_a?(OkConsumer)
end

Karafka::App.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:type]
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer OkConsumer
    end

    topic DT.topics[1] do
      consumer NotOkConsumer
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

produce_many(DT.topics[0], DT.uuids(10))
produce_many(DT.topics[1], DT.uuids(10))

start_karafka_and_wait_until do
  DT.key?(:ok) && DT.key?(:not_ok) && DT[:accepted].size >= 20
end

classes = ->(name) { DT[name].map(&:class).uniq.sort_by(&:name) }

assert_equal [NotOkConsumer, OkConsumer], classes.call("consumer.initialize")
assert_equal [OkConsumer], classes.call("consumer.initialized")
assert_equal %w[consumer.initialized.error], DT[:errors].uniq

%w[
  consumer.before_schedule_consume
  consumer.consume
  consumer.consumed
  consumer.before_schedule_shutdown
  consumer.shutting_down
  consumer.shutdown
].each do |event_name|
  assert_equal [NotOkConsumer, OkConsumer], classes.call(event_name), event_name
  assert(DT[event_name].all? { |consumer| consumer.is_a?(Karafka::ShareConsumer) })
end

# One consume/consumed pair per consume job
assert_equal DT[:batches], DT[:consume_sizes]
assert_equal DT[:batches], DT[:consumed_sizes]
assert_equal DT["consumer.consume"].size, DT["consumer.consumed"].size
assert_equal DT["consumer.consume"].size, DT["consumer.before_schedule_consume"].size
# Shutdown runs once per consumer
assert_equal 2, DT["consumer.shutdown"].size
