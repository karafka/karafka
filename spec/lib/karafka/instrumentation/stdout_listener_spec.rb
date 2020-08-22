# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::StdoutListener do
  subject(:listener) { described_class.new }

  let(:event) { Dry::Events::Event.new(rand.to_s, payload) }
  let(:time) { rand }
  let(:topic) { build(:routing_topic, name: topic_name) }
  let(:topic_name) { rand.to_s }

  describe '#on_params_params_deserialize' do
    subject(:trigger) { listener.on_params_params_deserialize(event) }

    let(:topic) { rand.to_s }
    let(:payload) { { caller: caller, time: time } }
    let(:caller) { instance_double(Karafka::Params::Params, metadata: metadata) }
    let(:metadata) { instance_double(Karafka::Params::Metadata, topic: topic) }
    let(:message) { "Params deserialization for #{topic} topic successful in #{time} ms" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:debug).with(message)
      trigger
    end
  end

  describe '#on_params_params_deserialize_error' do
    subject(:trigger) { listener.on_params_params_deserialize_error(event) }

    let(:topic_name) { rand.to_s }
    let(:payload) { { caller: caller, time: time, error: error } }
    let(:error) { Karafka::Errors::DeserializationError }
    let(:caller) { instance_double(Karafka::Params::Params, metadata: metadata) }
    let(:metadata) { instance_double(Karafka::Params::Metadata, topic: topic_name) }
    let(:message) { "Params deserialization error for #{topic_name} topic: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:error).with(message)
      trigger
    end
  end

  describe '#on_connection_listener_fetch_loop_error' do
    subject(:trigger) { listener.on_connection_listener_fetch_loop_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError }
    let(:message) { "Listener fetch loop error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:error).with(message)
      trigger
    end
  end

  describe '#on_connection_client_fetch_loop_error' do
    subject(:trigger) { listener.on_connection_client_fetch_loop_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError }
    let(:message) { "Client fetch loop error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:error).with(message)
      trigger
    end
  end

  describe '#on_fetcher_call_error' do
    subject(:trigger) { listener.on_fetcher_call_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError }
    let(:message) { "Fetcher crash due to an error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:fatal).with(message)
      trigger
    end
  end

  describe '#on_backends_inline_process' do
    subject(:trigger) { listener.on_backends_inline_process(event) }

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
    subject(:trigger) { listener.on_process_notice_signal(event) }

    let(:payload) { { signal: -1 } }
    let(:message) { "Received #{event[:signal]} system signal" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:info).with(message)
      trigger
    end
  end

  describe '#on_consumers_responders_respond_with' do
    subject(:trigger) { listener.on_consumers_responders_respond_with(event) }

    let(:consumer_instance) { consumer_class.new(topic) }
    let(:data) { [rand] }
    let(:payload) { { caller: consumer_instance, data: data } }
    let(:responder) { Karafka::BaseResponder }
    let(:message) do
      "Responded from #{consumer_instance.class} using #{responder} with following data #{data}"
    end
    let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
    let(:topic) do
      build(:routing_topic).tap do |topic|
        topic.responder = responder
      end
    end

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:info).with(message)
      trigger
    end
  end

  describe '#on_connection_batch_delegator_call' do
    subject(:trigger) { listener.on_connection_batch_delegator_call(event) }

    let(:payload) { { caller: caller, consumer: consumer, kafka_batch: kafka_batch } }
    let(:kafka_messages) { Array.new(rand(2..10)) { rand } }
    let(:kafka_batch) { instance_double(Kafka::FetchedBatch, messages: kafka_messages) }
    let(:caller) { Karafka::Connection::BatchDelegator }
    let(:consumer) { instance_double(Karafka::BaseConsumer, topic: topic) }
    let(:message) do
      "#{kafka_messages.count} messages on #{topic.name} topic delegated to #{consumer.class}"
    end

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:info).with(message)
      trigger
    end
  end

  describe '#on_connection_message_delegator_call' do
    subject(:trigger) { listener.on_connection_message_delegator_call(event) }

    let(:payload) { { caller: caller, consumer: consumer, kafka_message: kafka_message } }
    let(:kafka_message) { rand }
    let(:caller) { Karafka::Connection::MessageDelegator }
    let(:consumer) { instance_double(Karafka::BaseConsumer, topic: topic) }
    let(:message) { "1 message on #{topic.name} topic delegated to #{consumer.class}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to receive(:info).with(message)
      trigger
    end
  end

  describe '#on_app_initializing' do
    subject(:trigger) { listener.on_app_initializing(event) }

    let(:payload) { {} }
    let(:message) { "Initializing Karafka server #{::Process.pid}" }

    it 'expect logger to log server initializing' do
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to receive(:info).with(message).at_least(:once)
      trigger
    end
  end

  describe '#on_app_running' do
    subject(:trigger) { listener.on_app_running(event) }

    let(:payload) { {} }
    let(:message) { "Running Karafka server #{::Process.pid}" }

    it 'expect logger to log server running' do
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to receive(:info).with(message).at_least(:once)
      trigger
    end
  end

  describe '#on_app_stopping' do
    subject(:trigger) { listener.on_app_stopping(event) }

    let(:payload) { {} }
    let(:message) { "Stopping Karafka server #{::Process.pid}" }

    it 'expect logger to log server stop' do
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to receive(:info).with(message).at_least(:once)
      trigger
      # This sleep ensures that the threaded logger is able to finish
      sleep 0.1
    end
  end

  describe '#on_app_stopping_error' do
    subject(:trigger) { listener.on_app_stopping_error(event) }

    let(:payload) { {} }
    let(:message) { "Forceful Karafka server #{::Process.pid} stop" }

    it 'expect logger to log server stop' do
      expect(Karafka.logger).to receive(:error).with(message).at_least(:once)
      trigger
      # This sleep ensures that the threaded logger is able to finish
      sleep 0.1
    end
  end
end
