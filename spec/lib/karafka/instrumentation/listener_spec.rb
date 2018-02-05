# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::Listener do
  let(:event) { Dry::Events::Event.new(rand, payload) }
  let(:time) { rand }
  let(:topic) { instance_double(Karafka::Routing::Topic, name: topic_name) }
  let(:topic_name) { rand.to_s }

  describe '#on_params_params_parse' do
    subject(:trigger) { described_class.on_params_params_parse(event) }

    let(:topic) { rand.to_s }
    let(:payload) { { caller: caller, time: time } }
    let(:caller) { instance_double(Karafka::Params::Params, topic: topic) }
    let(:message) { "Params parsing for #{topic} topic successful in #{time} ms" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:debug).with(message)
      trigger
    end
  end

  describe '#on_params_params_parse_error' do
    subject(:trigger) { described_class.on_params_params_parse_error(event) }

    let(:topic_name) { rand.to_s }
    let(:payload) { { caller: caller, time: time, error: error } }
    let(:error) { Karafka::Errors::ParserError }
    let(:caller) { instance_double(Karafka::Params::Params, topic: topic_name) }
    let(:message) { "Params parsing error for #{topic_name} topic: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:error).with(message)
      trigger
    end
  end

  describe '#on_connection_listener_fetch_loop_error' do
    subject(:trigger) { described_class.on_connection_listener_fetch_loop_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError }
    let(:message) { "Listener fetch loop error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:error).with(message)
      trigger
    end
  end

  describe '#on_connection_client_fetch_loop_error' do
    subject(:trigger) { described_class.on_connection_client_fetch_loop_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError }
    let(:message) { "Client fetch loop error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:error).with(message)
      trigger
    end
  end

  describe '#on_fetcher_call_error' do
    subject(:trigger) { described_class.on_fetcher_call_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError }
    let(:message) { "Fetcher crash due to an error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:fatal).with(message)
      trigger
    end
  end

  describe '#on_backends_inline_process' do
    subject(:trigger) { described_class.on_backends_inline_process(event) }

    let(:payload) { { caller: caller, time: time } }
    let(:params_batch) { [1] }
    let(:count) { params_batch.size }
    let(:message) do
      "Inline processing of topic #{topic_name} with #{count} messages took #{time} ms"
    end
    let(:caller) do
      instance_double(
        Karafka::BaseConsumer,
        params_batch: params_batch,
        topic: topic
      )
    end

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:info).with(message)
      trigger
    end
  end

  describe '#on_process_notice_signal' do
    subject(:trigger) { described_class.on_process_notice_signal(event) }

    let(:payload) { { signal: -1 } }
    let(:message) { "Received #{event[:signal]} system signal" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:info).with(message)
      trigger
    end
  end

  describe '#on_consumers_responders_respond_with' do
    subject(:trigger) { described_class.on_consumers_responders_respond_with(event) }

    let(:controller_instance) { controller_class.new }
    let(:data) { [rand] }
    let(:payload) { { caller: controller_instance, data: data } }
    let(:responder) { Karafka::BaseResponder }
    let(:message) do
      "Responded from #{controller_instance.class} using #{responder} with following data #{data}"
    end
    let(:controller_class) do
      ClassBuilder.inherit(Karafka::BaseConsumer).tap do |klass|
        klass.topic = topic
      end
    end
    let(:topic) do
      instance_double(
        Karafka::Routing::Topic,
        responder: responder,
        backend: :inline,
        batch_consuming: false
      )
    end

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:info).with(message)
      trigger
    end
  end

  describe '#on_connection_delegator_call' do
    subject(:trigger) { described_class.on_connection_delegator_call(event) }

    let(:payload) { { caller: caller, consumer: consumer, kafka_messages: kafka_messages } }
    let(:kafka_messages) { Array.new(rand(2..10)) { rand } }
    let(:caller) { Karafka::Connection::Delegator }
    let(:consumer) { instance_double(Karafka::BaseConsumer, topic: topic) }
    let(:message) do
      "#{kafka_messages.count} messages on #{topic.name} topic delegated to #{consumer.class}"
    end

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:info).with(message)
      trigger
    end
  end
end
