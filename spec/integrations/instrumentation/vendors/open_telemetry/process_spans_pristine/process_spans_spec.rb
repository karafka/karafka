# frozen_string_literal: true

# Karafka OpenTelemetry listener should trace each consumed batch with a process span that is
# current in `#consume`, record consumption errors on it without leaking it and link it to the
# producers trace contexts from the message headers

require "karafka"
require "opentelemetry/sdk"
require "karafka/instrumentation/vendors/open_telemetry/listener"

exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new

OpenTelemetry::SDK.configure do |c|
  c.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
end

tracer = OpenTelemetry.tracer_provider.tracer("karafka-integration")

# One worker thread, so a context the listener does not detach would leak into the next batches
setup_karafka(allow_errors: %w[consumer.consume.error]) { |config| config.concurrency = 1 }

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:current] << OpenTelemetry::Trace.current_span.context.valid?

    unless @raised
      @raised = true
      raise StandardError, "consume failed"
    end

    TRACER.in_span("user") do
      messages.each { |message| DT[0] << message.offset }
    end
  end
end

TRACER = tracer

Karafka.monitor.subscribe(
  Karafka::Instrumentation::Vendors::OpenTelemetry::Listener.new do |config|
    config.client = tracer
    config.links.active = true
    config.links.max_messages = 5
  end
)

# Subscribed after the listener, so it runs after the listener closed the span
Karafka.monitor.subscribe("worker.completed") do
  DT[:after] << OpenTelemetry::Trace.current_span.context.valid?
end

draw_routes(Consumer)

producer_span = tracer.start_span("producer")
headers = {}
OpenTelemetry.propagation.inject(
  headers,
  context: OpenTelemetry::Trace.context_with_span(producer_span)
)
producer_span.finish

produce_many(DT.topic, DT.uuids(10), headers: headers)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

spans = exporter.finished_spans
process_spans = spans.select { |span| span.name == "process #{DT.topic}" }
failed, *succeeded = process_spans
user_spans = spans.select { |span| span.name == "user" }

assert_equal OpenTelemetry::Trace::Status::ERROR, failed.status.code
assert_equal "consume failed", failed.status.description
assert succeeded.all? { |span| span.status.code == OpenTelemetry::Trace::Status::UNSET }
assert !user_spans.empty?

user_spans.each do |user_span|
  assert succeeded.map(&:span_id).include?(user_span.parent_span_id)
end

# Every batch gets a new root process span: the failed one did not leak into the next batches
assert process_spans.all? { |span| span.parent_span_id == OpenTelemetry::Trace::INVALID_SPAN_ID }
assert DT[:current].all?
assert_equal process_spans.size, DT[:current].size

process_spans.each do |span|
  assert_equal "kafka", span.attributes["messaging.system.name"]
  assert_equal DT.topic, span.attributes["messaging.destination.name"]
  assert_equal "0", span.attributes["messaging.destination.partition.id"]
  assert_equal Karafka::App.consumer_groups.first.id, span.attributes["messaging.consumer.group.name"]
  assert span.links.size <= 5
  assert span.links.all? { |link| link.span_context.span_id == producer_span.context.span_id }
end

assert !DT[:after].empty?
assert DT[:after].none?
