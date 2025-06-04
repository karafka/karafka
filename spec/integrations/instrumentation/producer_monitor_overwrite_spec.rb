# frozen_string_literal: true

# You should be able to use a custom monitor for the producer

class WaterdropTracingMonitor < WaterDrop::Instrumentation::Monitor
  INTERCEPTED_KARAFKA_EVENTS = %w[
    message.produced_async
    messages.produced_async
    message.produced_sync
    messages.produced_sync
  ].freeze

  def initialize(
    notifications_bus = ::WaterDrop::Instrumentation::Notifications.new,
    namespace = nil,
    service_name: nil
  )
    super(notifications_bus, namespace)
    @service_name = service_name
  end

  def instrument(event_id, event = EMPTY_HASH, &block)
    return super unless INTERCEPTED_KARAFKA_EVENTS.include?(event_id)

    DT[:intercepted] = true

    super
  end
end

setup_karafka

Karafka::App.config.producer = ::WaterDrop::Producer.new do |p_config|
  p_config.kafka = ::Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  p_config.monitor = WaterdropTracingMonitor.new
end

Karafka.producer.monitor.subscribe('message.produced_sync') do |event|
  DT[:triggered] << event
end

Karafka.producer.produce_sync(topic: DT.topic, payload: '')

assert DT.key?(:triggered)
assert DT.key?(:intercepted)
