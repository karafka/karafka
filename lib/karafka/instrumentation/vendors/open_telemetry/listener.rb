# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Vendors
      # OpenTelemetry specific instrumentation
      module OpenTelemetry
        # Listener that traces each consumed batch with an OpenTelemetry "process" span.
        #
        # The span is current while `#consume` runs, so spans created in user code nest under it.
        # It depends on the `opentelemetry-api` gem, which is not a Karafka dependency.
        #
        # @example Subscribe it with an OpenTelemetry tracer
        #   listener = Karafka::Instrumentation::Vendors::OpenTelemetry::Listener.new do |config|
        #     config.client = OpenTelemetry.tracer_provider.tracer("karafka")
        #   end
        #
        #   Karafka.monitor.subscribe(listener)
        class Listener
          include Karafka::Core::Configurable
          extend Forwardable

          def_delegators :config, :client, :links

          # Reads the trace context from message headers. A header key present more than once
          # comes as an array of values and we use the last one.
          module HeadersGetter
            class << self
              # @param carrier [Hash] message headers
              # @param key [String] header key
              # @return [String, nil] header value
              def get(carrier, key)
                value = carrier[key]
                value.is_a?(Array) ? value.last : value
              end

              # @param carrier [Hash] message headers
              # @return [Array<String>] header keys
              def keys(carrier)
                carrier.keys
              end
            end
          end

          private_constant :HeadersGetter

          # `OpenTelemetry::Trace::Tracer` that we should use to trace stuff
          setting :client

          # Span links to the trace context of each message's producer, extracted from the
          # message headers. Extraction deserializes the headers of each linked message.
          setting :links do
            # Should we link the span to the producers' trace contexts
            setting :active, default: false
            # Maximum number of messages of a batch to extract the trace context from
            setting :max_messages, default: 128
          end

          configure

          # @param block [Proc] configuration block
          def initialize(&block)
            configure
            setup(&block) if block
            @span_key = :"karafka_open_telemetry_listener_span_#{object_id}"
          end

          # @note We define this alias to be consistent with `WaterDrop#setup`
          def setup(&)
            configure(&)
          end

          # Opens the process span and makes it current for the user consumption code
          #
          # @param event [Karafka::Core::Monitoring::Event] event details including payload
          def on_consumer_consume(event)
            # Closes a span that leaked from a previous batch of this thread, if any
            finish_span

            consumer = event[:caller]
            topic = consumer.topic
            messages = consumer.messages
            topic_name = topic.name

            span = client.start_span(
              "process #{topic_name}",
              kind: :consumer,
              links: build_links(messages),
              attributes: {
                "messaging.system.name" => "kafka",
                "messaging.operation.name" => "process",
                "messaging.operation.type" => "process",
                "messaging.destination.name" => topic_name,
                "messaging.destination.partition.id" => consumer.partition.to_s,
                "messaging.consumer.group.name" => topic.subscription_group.group_id,
                "messaging.batch.message_count" => messages.size,
                "kafka.offset" => messages.metadata.first_offset
              }
            )

            token = ::OpenTelemetry::Context.attach(
              ::OpenTelemetry::Trace.context_with_span(span)
            )

            Thread.current[@span_key] = [span, token]
          end

          # Closes the process span after a successful consumption
          #
          # @param _event [Karafka::Core::Monitoring::Event] event details including payload
          def on_consumer_consumed(_event)
            finish_span
          end

          # Records the consumption error on the process span and closes it, because
          # `consumer.consumed` is not published when `#consume` raises
          #
          # @param event [Karafka::Core::Monitoring::Event] event details including payload
          def on_error_occurred(event)
            return unless event[:type] == "consumer.consume.error"

            span, = Thread.current[@span_key]

            return unless span

            error = event[:error]
            span.record_exception(error)
            span.status = ::OpenTelemetry::Trace::Status.error(error.message)

            finish_span
          end

          # Closes the process span also when neither `consumer.consumed` nor
          # `consumer.consume.error` was published for it
          #
          # @param _event [Karafka::Core::Monitoring::Event] event details including payload
          def on_worker_completed(_event)
            finish_span
          end

          private

          # Finishes the span opened by this listener in the current thread and restores the
          # context that was current before it
          def finish_span
            span, token = Thread.current[@span_key]

            return unless span

            Thread.current[@span_key] = nil
            span.finish
            ::OpenTelemetry::Context.detach(token)
          end

          # @param messages [Karafka::Messages::Messages] consumed batch
          # @return [Array<OpenTelemetry::Trace::Link>, nil] links to the valid trace contexts
          #   extracted from the first `links.max_messages` messages headers or nil when off or
          #   when none of those messages carries a valid trace context
          def build_links(messages)
            return unless links.active

            propagation = ::OpenTelemetry.propagation
            empty_context = ::OpenTelemetry::Context.empty

            # We use the raw array not to trigger instrumentation that patches `Messages#each`
            built = messages.raw.first(links.max_messages).filter_map do |message|
              span_context = ::OpenTelemetry::Trace.current_span(
                propagation.extract(message.headers, context: empty_context, getter: HeadersGetter)
              ).context

              ::OpenTelemetry::Trace::Link.new(span_context) if span_context.valid?
            # Tracing must never fail the consumption, so we skip headers we cannot extract from
            rescue
              nil
            end

            built.empty? ? nil : built
          end
        end
      end
    end
  end
end
