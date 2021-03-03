# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:event) { Dry::Events::Event.new(rand.to_s, payload) }
  let(:time) { rand }
  let(:topic) { build(:routing_topic, name: topic_name) }
  let(:topic_name) { rand.to_s }

  before do
    allow(Karafka.logger).to receive(:info)
    allow(Karafka.logger).to receive(:error)
    allow(Karafka.logger).to receive(:fatal)

    trigger
  end

  describe '#on_connection_listener_fetch_loop_error' do
    subject(:trigger) { listener.on_connection_listener_fetch_loop_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError.new }
    let(:message) { "Listener fetch loop error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:error).with(message)
    end
  end

  describe '#on_connection_listener_fetch_loop' do
    subject(:trigger) { listener.on_connection_listener_fetch_loop(event) }

    let(:payload) { { caller: caller } }
    let(:message) { 'Receiving new messages from Kafka...' }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:info).with(message)
    end
  end

  describe '#on_connection_listener_fetch_loop_received' do
    subject(:trigger) { listener.on_connection_listener_fetch_loop_received(event) }

    let(:payload) { { caller: caller, messages_buffer: Array.new(5) } }
    let(:message) { 'Received 5 new messages from Kafka' }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:info).with(message)
    end
  end

  describe '#on_consumer_consume_error' do
    subject(:trigger) { listener.on_consumer_consume_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError.new }
    let(:message) { "Consuming failed due to an error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:error).with(message)
    end
  end

  describe '#on_consumer_revoked_error' do
    subject(:trigger) { listener.on_consumer_revoked_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError.new }
    let(:message) { "Revoking failed due to an error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:error).with(message)
    end
  end

  describe '#on_consumer_shutdown_error' do
    subject(:trigger) { listener.on_consumer_shutdown_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError.new }
    let(:message) { "Shutting down failed due to an error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:error).with(message)
    end
  end

  describe '#on_runner_call_error' do
    subject(:trigger) { listener.on_runner_call_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError.new }
    let(:message) { "Runner crash due to an error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:fatal).with(message)
    end
  end

  describe '#on_process_notice_signal' do
    subject(:trigger) { listener.on_process_notice_signal(event) }

    let(:payload) { { signal: -1 } }
    let(:message) { "Received #{event[:signal]} system signal" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:info).with(message)
    end
  end

  describe '#on_app_initializing' do
    subject(:trigger) { listener.on_app_initializing(event) }

    let(:payload) { {} }
    let(:message) { 'Initializing Karafka framework' }

    it 'expect logger to log framework initializing' do
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_running' do
    subject(:trigger) { listener.on_app_running(event) }

    let(:payload) { {} }
    let(:message) { 'Running Karafka server' }

    it 'expect logger to log server running' do
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_stopping' do
    subject(:trigger) { listener.on_app_stopping(event) }

    let(:payload) { {} }
    let(:message) { 'Stopping Karafka server' }

    it 'expect logger to log server stop' do
      # This sleep ensures that the threaded logger is able to finish
      sleep 0.1
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_stopped' do
    subject(:trigger) { listener.on_app_stopped(event) }

    let(:payload) { {} }
    let(:message) { 'Stopped Karafka server' }

    it 'expect logger to log server stopped' do
      sleep 0.1
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_stopping_error' do
    subject(:trigger) { listener.on_app_stopping_error(event) }

    let(:payload) { {} }
    let(:message) { 'Forceful Karafka server stop' }

    it 'expect logger to log server stop' do
      # This sleep ensures that the threaded logger is able to finish
      sleep 0.1
      expect(Karafka.logger).to have_received(:error).with(message).at_least(:once)
    end
  end

  describe '#on_worker_process_error' do
    subject(:trigger) { listener.on_worker_process_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { Exception.new }
    let(:message) { "Worker processing failed due to an error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:fatal).with(message)
    end
  end

  describe '#on_emitted_error' do
    subject(:trigger) { listener.on_emitted_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { Exception.new }
    let(:message) { "Background thread error emitted: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:error).with(message)
    end
  end
end
