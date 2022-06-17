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

  describe '#on_connection_listener_fetch_loop' do
    subject(:trigger) { listener.on_connection_listener_fetch_loop(event) }

    let(:connection_listener) { instance_double(Karafka::Connection::Listener, id: 'id') }
    let(:payload) { { caller: connection_listener, time: 2 } }
    let(:message) { '[id] Polling messages...' }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:info).with(message)
    end
  end

  describe '#on_connection_listener_fetch_loop_received' do
    subject(:trigger) { listener.on_connection_listener_fetch_loop_received(event) }

    let(:connection_listener) { instance_double(Karafka::Connection::Listener, id: 'id') }
    let(:payload) { { caller: connection_listener, messages_buffer: Array.new(5), time: 2 } }
    let(:message) { '[id] Polled 5 messages in 2ms' }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:info).with(message)
    end
  end

  describe '#on_worker_process' do
    subject(:trigger) { listener.on_worker_process(event) }

    let(:job) { ::Karafka::Processing::Jobs::Shutdown.new(executor) }
    let(:executor) { build(:processing_executor) }
    let(:payload) { { job: job } }

    it { expect(Karafka.logger).to have_received(:info) }
  end

  describe '#on_worker_processed' do
    subject(:trigger) { listener.on_worker_processed(event) }

    let(:job) { ::Karafka::Processing::Jobs::Shutdown.new(executor) }
    let(:executor) { build(:processing_executor) }
    let(:payload) { { job: job, time: 2 } }

    it { expect(Karafka.logger).to have_received(:info) }
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

  describe '#on_error_occurred' do
    subject(:trigger) { listener.on_error_occurred(event) }

    let(:payload) { { caller: caller, error: error, type: type } }
    let(:error) { StandardError.new }

    context 'when it is a connection.listener.fetch_loop.error' do
      let(:message) { "Listener fetch loop error: #{error}" }
      let(:type) { 'connection.listener.fetch_loop.error' }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a consumer.before_consume.error' do
      let(:type) { 'consumer.before_consume.error' }
      let(:message) { "Consumer before consume error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a consumer.consume.error' do
      let(:type) { 'consumer.consume.error' }
      let(:message) { "Consumer consuming error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a consumer.revoked.error' do
      let(:type) { 'consumer.revoked.error' }
      let(:message) { "Consumer on revoked failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a consumer.shutdown.error' do
      let(:type) { 'consumer.shutdown.error' }
      let(:message) { "Consumer on shutdown failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a runner.call.error' do
      let(:type) { 'runner.call.error' }
      let(:message) { "Runner crashed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:fatal).with(message) }
    end

    context 'when it is an app.stopping.error' do
      let(:type) { 'app.stopping.error' }
      let(:payload) { { type: type, error: Karafka::Errors::ForcefulShutdownError.new } }
      let(:message) { 'Forceful Karafka server stop' }

      it 'expect logger to log server stop' do
        # This sleep ensures that the threaded logger is able to finish
        sleep 0.1
        expect(Karafka.logger).to have_received(:error).with(message).at_least(:once)
      end

      context 'when it is a licenser.expired error' do
        let(:type) { 'licenser.expired' }
        let(:error) { Karafka::Errors::ExpiredLicenseTokenError.new }
        let(:message) { '' }

        it { expect(Karafka.logger).to have_received(:error).with(message) }
      end
    end

    context 'when it is a worker.process.error' do
      let(:type) { 'worker.process.error' }
      let(:message) { "Worker processing failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:fatal).with(message) }
    end

    context 'when it is a librdkafka.error' do
      let(:type) { 'librdkafka.error' }
      let(:message) { "librdkafka internal error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is an unsupported error type' do
      subject(:error_trigger) { listener.on_error_occurred(event) }

      # We use the before { trigger } for all other cases and not worth duplicating, that's why
      # we overwrite it here
      let(:trigger) { nil }
      let(:type) { 'unsupported.error' }

      it { expect { error_trigger }.to raise_error(Karafka::Errors::UnsupportedCaseError) }
    end
  end
end
