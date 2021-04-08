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
    let(:error) { StandardError }
    let(:message) { "Listener fetch loop error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:error).with(message)
    end
  end

  describe '#on_connection_client_fetch_loop_error' do
    subject(:trigger) { listener.on_connection_client_fetch_loop_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError }
    let(:message) { "Client fetch loop error: #{error}" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:error).with(message)
    end
  end

  describe '#on_runner_call_error' do
    subject(:trigger) { listener.on_runner_call_error(event) }

    let(:payload) { { caller: caller, error: error } }
    let(:error) { StandardError }
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
    let(:message) { "Initializing Karafka server #{::Process.pid}" }

    it 'expect logger to log server initializing' do
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_running' do
    subject(:trigger) { listener.on_app_running(event) }

    let(:payload) { {} }
    let(:message) { "Running Karafka server #{::Process.pid}" }

    it 'expect logger to log server running' do
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_stopping' do
    subject(:trigger) { listener.on_app_stopping(event) }

    let(:payload) { {} }
    let(:message) { "Stopping Karafka server #{::Process.pid}" }

    it 'expect logger to log server stop' do
      # This sleep ensures that the threaded logger is able to finish
      sleep 0.1
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_stopping_error' do
    subject(:trigger) { listener.on_app_stopping_error(event) }

    let(:payload) { {} }
    let(:message) { "Forceful Karafka server #{::Process.pid} stop" }

    it 'expect logger to log server stop' do
      # This sleep ensures that the threaded logger is able to finish
      sleep 0.1
      expect(Karafka.logger).to have_received(:error).with(message).at_least(:once)
    end
  end
end
