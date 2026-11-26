# frozen_string_literal: true

require "opentelemetry/sdk"
require "karafka/instrumentation/vendors/open_telemetry/listener"

RSpec.describe_current do
  subject(:listener) do
    described_class.new do |config|
      config.client = tracer
    end
  end

  let(:exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:tracer_provider) do
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)
    )
    provider
  end
  let(:tracer) { tracer_provider.tracer("karafka-spec") }
  let(:topic_kafka) { {} }
  let(:topic) do
    topics = Karafka::Routing::Topics.new([build(:routing_topic, kafka: topic_kafka)])
    build(:routing_subscription_group, topics: topics).topics.first
  end
  let(:raw_headers) { [{}, {}] }
  let(:messages) do
    raw_headers.map.with_index do |headers, index|
      build(:messages_message, topic: topic.name, offset: 10 + index, raw_headers: headers)
    end
  end
  let(:consumer) do
    consumer = Karafka::BaseConsumer.new
    consumer.coordinator = build(:processing_coordinator, topic: topic, partition: 2)
    consumer.messages = Karafka::Messages::Builders::Messages.call(messages, topic, 2, Time.now)
    consumer
  end
  let(:consume_event) { Karafka::Core::Monitoring::Event.new("consumer.consume", caller: consumer) }
  let(:consumed_event) do
    Karafka::Core::Monitoring::Event.new("consumer.consumed", caller: consumer)
  end
  let(:error) { StandardError.new("consume failed") }
  let(:error_event) do
    Karafka::Core::Monitoring::Event.new(
      "error.occurred",
      caller: consumer,
      error: error,
      type: "consumer.consume.error"
    )
  end
  let(:completed_event) { Karafka::Core::Monitoring::Event.new("worker.completed", {}) }
  let(:finished_spans) { exporter.finished_spans }
  let(:process_span) { finished_spans.find { |span| span.name == "process #{topic.name}" } }

  after { OpenTelemetry::Context.clear }

  it { expect(NotificationsChecker.valid?(listener)).to be(true) }

  context "when consumption succeeds" do
    before do
      listener.on_consumer_consume(consume_event)
      tracer.in_span("user") { nil }
      listener.on_consumer_consumed(consumed_event)
      listener.on_worker_completed(completed_event)
    end

    it "expect to finish exactly one process span with no error" do
      expect(finished_spans.map(&:name)).to eq(["user", "process #{topic.name}"])
      expect(process_span.status.code).to eq(OpenTelemetry::Trace::Status::UNSET)
      expect(process_span.kind).to eq(:consumer)
    end

    it "expect to nest the user span under the process span" do
      user_span = finished_spans.find { |span| span.name == "user" }

      expect(user_span.parent_span_id).to eq(process_span.span_id)
      expect(user_span.trace_id).to eq(process_span.trace_id)
    end

    it "expect to restore the previous context" do
      expect(OpenTelemetry::Trace.current_span).to eq(OpenTelemetry::Trace::Span::INVALID)
    end

    it "expect to set the messaging attributes" do
      expect(process_span.attributes).to eq(
        "messaging.system.name" => "kafka",
        "messaging.operation.name" => "process",
        "messaging.operation.type" => "process",
        "messaging.destination.name" => topic.name,
        "messaging.destination.partition.id" => "2",
        "messaging.consumer.group.name" => topic.consumer_group.id,
        "messaging.batch.message_count" => 2,
        "kafka.offset" => 10
      )
    end

    it "expect not to add links by default" do
      expect(process_span.links).to be_nil
    end

    context "when the topic sets its own Kafka group.id" do
      let(:topic_kafka) { { "group.id": "legacy-group" } }

      it "expect to use the Kafka consumer group name" do
        expect(process_span.attributes["messaging.consumer.group.name"]).to eq("legacy-group")
      end
    end
  end

  context "when consumption raises" do
    before do
      listener.on_consumer_consume(consume_event)
      listener.on_error_occurred(error_event)
      listener.on_worker_completed(completed_event)
    end

    it "expect to finish the process span once with the error recorded" do
      expect(finished_spans.size).to eq(1)
      expect(process_span.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
      expect(process_span.status.description).to eq("consume failed")
      expect(process_span.events.map(&:name)).to eq(["exception"])
    end

    it "expect to restore the previous context" do
      expect(OpenTelemetry::Trace.current_span).to eq(OpenTelemetry::Trace::Span::INVALID)
    end
  end

  context "when neither consumer.consumed nor the consume error is published" do
    before do
      listener.on_consumer_consume(consume_event)
      listener.on_worker_completed(completed_event)
    end

    it "expect worker.completed to finish the process span and restore the context" do
      expect(finished_spans.size).to eq(1)
      expect(OpenTelemetry::Trace.current_span).to eq(OpenTelemetry::Trace::Span::INVALID)
    end
  end

  context "when another error type occurs" do
    let(:other_error_event) do
      Karafka::Core::Monitoring::Event.new(
        "error.occurred",
        caller: consumer,
        error: error,
        type: "consumer.revoked.error"
      )
    end

    before do
      listener.on_consumer_consume(consume_event)
      listener.on_error_occurred(other_error_event)
    end

    it "expect not to finish the process span" do
      expect(finished_spans).to be_empty
    end
  end

  context "when the previous span of this thread leaked" do
    before do
      listener.on_consumer_consume(consume_event)
      listener.on_consumer_consume(consume_event)
      listener.on_consumer_consumed(consumed_event)
    end

    it "expect to finish both spans and restore the context" do
      expect(finished_spans.size).to eq(2)
      expect(OpenTelemetry::Trace.current_span).to eq(OpenTelemetry::Trace::Span::INVALID)
    end
  end

  context "when links are active" do
    let(:producer_spans) { Array.new(3) { tracer.start_span("producer").tap(&:finish) } }
    let(:trace_headers) do
      lambda do |span|
        headers = {}
        OpenTelemetry.propagation.inject(
          headers,
          context: OpenTelemetry::Trace.context_with_span(span)
        )
        headers
      end
    end
    let(:raw_headers) { producer_spans.map(&trace_headers) + [{}] }
    let(:max_messages) { 128 }

    before do
      OpenTelemetry.propagation = OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator

      listener.setup do |config|
        config.links.active = true
        config.links.max_messages = max_messages
      end

      listener.on_consumer_consume(consume_event)
      listener.on_consumer_consumed(consumed_event)
    end

    after { OpenTelemetry.propagation = OpenTelemetry::Context::Propagation::NoopTextMapPropagator.new }

    it "expect to link the producers trace contexts and skip messages without one" do
      expect(process_span.links.map { |link| link.span_context.span_id })
        .to eq(producer_spans.map { |span| span.context.span_id })
    end

    context "when the batch has more messages than the cap" do
      let(:max_messages) { 2 }

      it "expect to link only the first max_messages messages" do
        expect(process_span.links.map { |link| link.span_context.span_id })
          .to eq(producer_spans.first(2).map { |span| span.context.span_id })
      end
    end

    context "when no message carries a trace context" do
      let(:raw_headers) { [{}, {}] }

      it { expect(process_span.links).to be_nil }
    end

    context "when a span is current while no message carries a trace context" do
      let(:raw_headers) { [{}, {}] }

      before do
        listener.on_worker_completed(completed_event)

        tracer.in_span("outer") do
          listener.on_consumer_consume(consume_event)
          listener.on_consumer_consumed(consumed_event)
        end
      end

      it "expect not to link the current span" do
        expect(finished_spans.select { |span| span.name == "process #{topic.name}" }.map(&:links))
          .to eq([nil, nil])
      end
    end

    context "when a message has the trace context header more than once" do
      let(:raw_headers) do
        [{ "traceparent" => producer_spans.first(2).map { |span| trace_headers.call(span)["traceparent"] } }]
      end

      it "expect to link the trace context from the last value" do
        expect(process_span.links.map { |link| link.span_context.span_id })
          .to eq([producer_spans[1].context.span_id])
      end
    end

    context "when extraction of a message trace context raises" do
      let(:raw_headers) { [{ "traceparent" => Object.new }, trace_headers.call(producer_spans.first)] }

      it "expect to skip only that message and still link the others" do
        expect(process_span.links.map { |link| link.span_context.span_id })
          .to eq([producer_spans.first.context.span_id])
      end
    end
  end
end
