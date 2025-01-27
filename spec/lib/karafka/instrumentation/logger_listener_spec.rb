# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:event) { Karafka::Core::Monitoring::Event.new(rand.to_s, payload) }
  let(:time) { rand }
  let(:topic) { build(:routing_topic, name: topic_name) }
  let(:topic_name) { rand.to_s }
  let(:server_id) { Karafka::Server.id }
  let(:client_id) { rand.to_s }

  before do
    Karafka::Server.listeners = []
    Karafka::Server.workers = []

    allow(Karafka.logger).to receive(:debug)
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
      expect(Karafka.logger).to have_received(:debug).with(message)
    end

    context 'when log_polling is off' do
      subject(:listener) { described_class.new(log_polling: false) }

      it 'expect logger not to log' do
        expect(Karafka.logger).not_to have_received(:debug).with(message)
      end
    end
  end

  describe '#on_connection_listener_fetch_loop_received' do
    subject(:trigger) { listener.on_connection_listener_fetch_loop_received(event) }

    let(:connection_listener) { instance_double(Karafka::Connection::Listener, id: 'id') }

    context 'when there are no messages polled' do
      let(:payload) { { caller: connection_listener, messages_buffer: [], time: 2 } }
      let(:message) { '[id] Polled 0 messages in 2ms' }

      it 'expect logger to log proper message via debug level' do
        expect(Karafka.logger).to have_received(:debug).with(message)
      end
    end

    context 'when there were messages polled' do
      let(:payload) { { caller: connection_listener, messages_buffer: Array.new(5), time: 2 } }
      let(:message) { '[id] Polled 5 messages in 2ms' }

      it 'expect logger to log proper message via info level' do
        expect(Karafka.logger).to have_received(:info).with(message)
      end
    end

    context 'when log_polling is off' do
      subject(:listener) { described_class.new(log_polling: false) }

      let(:payload) { { caller: connection_listener, messages_buffer: [], time: 2 } }
      let(:message) { '[id] Polled 0 messages in 2ms' }

      it 'expect logger not to log' do
        expect(Karafka.logger).not_to have_received(:debug).with(message)
      end
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

  describe '#on_client_pause' do
    context 'when pausing offset is provided' do
      subject(:trigger) { listener.on_client_pause(event) }

      let(:client) { instance_double(Karafka::Connection::Client, id: SecureRandom.hex(6)) }
      let(:message) do
        "[#{client.id}] Pausing on topic Topic/0 on offset 12"
      end
      let(:payload) do
        {
          caller: client,
          topic: 'Topic',
          partition: 0,
          offset: 12
        }
      end

      it { expect(Karafka.logger).to have_received(:info).with(message) }
    end

    context 'when pausing offset is not provided (consecutive)' do
      subject(:trigger) { listener.on_client_pause(event) }

      let(:client) { instance_double(Karafka::Connection::Client, id: SecureRandom.hex(6)) }
      let(:message) do
        "[#{client.id}] Pausing on topic Topic/0 on the consecutive offset"
      end
      let(:payload) do
        {
          caller: client,
          topic: 'Topic',
          partition: 0,
          offset: nil
        }
      end

      it { expect(Karafka.logger).to have_received(:info).with(message) }
    end
  end

  describe '#on_client_resume' do
    subject(:trigger) { listener.on_client_resume(event) }

    let(:client) { instance_double(Karafka::Connection::Client, id: SecureRandom.hex(6)) }
    let(:message) do
      "[#{client.id}] Resuming on topic Topic/0"
    end
    let(:payload) do
      {
        caller: client,
        topic: 'Topic',
        partition: 0
      }
    end

    it { expect(Karafka.logger).to have_received(:info).with(message) }
  end

  describe '#on_consumer_consuming_retry' do
    subject(:trigger) { listener.on_consumer_consuming_retry(event) }

    let(:consumer) { Class.new(Karafka::BaseConsumer).new }
    let(:message) do
      <<~MSG.tr("\n", ' ').strip
        [#{consumer.id}] Retrying of #{consumer.class} after 100 ms on topic Topic/0 from offset 12
      MSG
    end
    let(:payload) do
      {
        caller: consumer,
        topic: 'Topic',
        partition: 0,
        offset: 12,
        timeout: 100
      }
    end

    it { expect(Karafka.logger).to have_received(:info).with(message) }
  end

  describe '#on_consumer_consuming_seek' do
    subject(:trigger) { listener.on_consumer_consuming_seek(event) }

    let(:consumer) { Class.new(Karafka::BaseConsumer).new }
    let(:kafka_message) { create(:messages_message) }
    let(:message) do
      <<~MSG.tr("\n", ' ').strip
        [#{consumer.id}] Seeking from #{consumer.class}
        on topic Topic/0 to offset #{kafka_message.offset}
      MSG
    end
    let(:payload) do
      {
        caller: consumer,
        topic: 'Topic',
        partition: 0,
        message: kafka_message
      }
    end

    it { expect(Karafka.logger).to have_received(:info).with(message) }
  end

  describe '#on_process_notice_signal' do
    subject(:trigger) { listener.on_process_notice_signal(event) }

    let(:payload) { { signal: :SIGTTIN } }
    let(:message) { "[#{server_id}] Received #{event[:signal]} system signal" }

    it 'expect logger to log proper message' do
      expect(Karafka.logger).to have_received(:info).with(message)
    end
  end

  describe '#on_app_running' do
    subject(:trigger) { listener.on_app_running(event) }

    let(:payload) { { server_id: server_id } }
    let(:message) { "[#{server_id}] Running Karafka #{Karafka::VERSION} server" }

    it 'expect logger to log server running' do
      # We had to add at least once as it runs in a separate thread and can interact
      # with other specs - this is a cheap workaround
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_quieting' do
    subject(:trigger) { listener.on_app_quieting(event) }

    let(:payload) { { server_id: server_id } }
    let(:message) { "[#{server_id}] Switching to quiet mode. New messages will not be processed" }

    it 'expect logger to log server quiet' do
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_quiet' do
    subject(:trigger) { listener.on_app_quiet(event) }

    let(:payload) { { server_id: server_id } }
    let(:message) { "[#{server_id}] Reached quiet mode. No messages will be processed anymore" }

    it 'expect logger to log server quiet' do
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_stopping' do
    subject(:trigger) { listener.on_app_stopping(event) }

    let(:payload) { { server_id: server_id } }
    let(:message) { "[#{server_id}] Stopping Karafka server" }

    it 'expect logger to log server stop' do
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_app_stopped' do
    subject(:trigger) { listener.on_app_stopped(event) }

    let(:payload) { { server_id: server_id } }
    let(:message) { "[#{server_id}] Stopped Karafka server" }

    it 'expect logger to log server stopped' do
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_dead_letter_queue_dispatched' do
    subject(:trigger) { listener.on_dead_letter_queue_dispatched(event) }

    let(:payload) { { caller: consumer, message: kafka_message } }
    let(:kafka_message) { create(:messages_message) }
    let(:coordinator) { create(:processing_coordinator, topic: topic) }
    let(:topic) { build(:routing_topic, name: 'test') }
    let(:message) do
      "[#{consumer.id}] Dispatched message #{kafka_message.offset} from test/0 to DLQ topic: dlq"
    end
    let(:consumer) do
      instance = Class.new(Karafka::BaseConsumer).new
      instance.coordinator = coordinator
      topic.dead_letter_queue(topic: 'dlq')
      instance
    end

    it { expect(Karafka.logger).to have_received(:info).with(message) }
  end

  describe '#on_filtering_throttled' do
    subject(:trigger) { listener.on_filtering_throttled(event) }

    let(:payload) { { caller: consumer, message: kafka_message } }
    let(:kafka_message) { create(:messages_message) }
    let(:coordinator) { create(:processing_coordinator, topic: topic) }
    let(:topic) { build(:routing_topic, name: 'test') }
    let(:message) do
      resume_offset = kafka_message.offset
      "[#{consumer.id}] Throttled and will resume from message #{resume_offset} on test/0"
    end
    let(:consumer) do
      instance = Class.new(Karafka::BaseConsumer).new
      instance.coordinator = coordinator
      topic.dead_letter_queue(topic: 'dlq')
      instance
    end

    it { expect(Karafka.logger).to have_received(:info).with(message) }
  end

  describe '#on_filtering_seek' do
    subject(:trigger) { listener.on_filtering_seek(event) }

    let(:payload) { { caller: consumer, message: kafka_message } }
    let(:kafka_message) { create(:messages_message) }
    let(:coordinator) { create(:processing_coordinator, topic: topic) }
    let(:topic) { build(:routing_topic, name: 'test') }
    let(:message) do
      seek_offset = kafka_message.offset
      "[#{consumer.id}] Post-filtering seeking to message #{seek_offset} on test/0"
    end
    let(:consumer) do
      instance = Class.new(Karafka::BaseConsumer).new
      instance.coordinator = coordinator
      topic.dead_letter_queue(topic: 'dlq')
      instance
    end

    it { expect(Karafka.logger).to have_received(:info).with(message) }
  end

  describe '#on_swarm_manager_stopping' do
    subject(:trigger) { listener.on_swarm_manager_stopping(event) }

    let(:node) { build(:swarm_node) }
    let(:payload) { { node: node } }
    let(:message) { "Swarm manager detected unhealthy node #{node.pid}. Sending TERM signal..." }

    it 'expect logger to log on error' do
      expect(Karafka.logger).to have_received(:error).with(message).at_least(:once)
    end
  end

  describe '#on_swarm_manager_terminating' do
    subject(:trigger) { listener.on_swarm_manager_terminating(event) }

    let(:node) { build(:swarm_node) }
    let(:payload) { { node: node } }
    let(:message) do
      "Swarm manager detected unresponsive node #{node.pid}. Sending KILL signal..."
    end

    it 'expect logger to log on error' do
      expect(Karafka.logger).to have_received(:error).with(message).at_least(:once)
    end
  end

  describe '#on_swarm_manager_before_fork' do
    subject(:trigger) { listener.on_swarm_manager_before_fork(event) }

    let(:node) { build(:swarm_node) }
    let(:payload) { { node: node } }
    let(:message) { "Swarm manager starting node with id: #{node.id}" }

    it 'expect logger to log on error' do
      expect(Karafka.logger).to have_received(:debug).with(message).at_least(:once)
    end
  end

  describe '#on_swarm_node_after_fork' do
    subject(:trigger) { listener.on_swarm_node_after_fork(event) }

    let(:node) { build(:swarm_node) }
    let(:payload) { { node: node } }
    let(:message) { "Swarm node #{::Process.pid} forked from #{::Process.ppid}" }

    it 'expect logger to log on error' do
      expect(Karafka.logger).to have_received(:info).with(message).at_least(:once)
    end
  end

  describe '#on_swarm_manager_control' do
    subject(:trigger) { listener.on_swarm_manager_control(event) }

    let(:manager) { Karafka::App.config.internal.swarm.manager }
    let(:payload) { { caller: manager } }
    let(:message) { "Swarm manager checking nodes: #{manager.nodes.map(&:pid).join(', ')}" }

    it 'expect logger to log on error' do
      expect(Karafka.logger).to have_received(:debug).with(message).at_least(:once)
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

    context 'when it is a consumer.initialized.error' do
      let(:type) { 'consumer.initialized.error' }
      let(:message) { "Consumer initialized error: #{error}" }

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

    context 'when it is a consumer.idle.error' do
      let(:type) { 'consumer.idle.error' }
      let(:message) { "Consumer idle failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a consumer.wrap.error' do
      let(:type) { 'consumer.wrap.error' }
      let(:message) { "Consumer wrap failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a consumer.tick.error' do
      let(:type) { 'consumer.tick.error' }
      let(:message) { "Consumer on tick failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a consumer.eofed.error' do
      let(:type) { 'consumer.eofed.error' }
      let(:message) { "Consumer on eofed failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a consumer.after_consume.error' do
      let(:type) { 'consumer.after_consume.error' }
      let(:message) { "Consumer on after_consume failed due to an error: #{error}" }

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

    context 'when it is a swarm.supervisor.error' do
      let(:type) { 'swarm.supervisor.error' }
      let(:message) { "Swarm supervisor crashed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:fatal).with(message) }
    end

    context 'when it is an app.stopping.error' do
      let(:type) { 'app.stopping.error' }
      let(:payload) { { type: type, error: Karafka::Errors::ForcefulShutdownError.new } }

      let(:message) do
        'Forceful Karafka server stop with: 0 active workers and 0 active listeners'
      end

      it 'expect logger to log server stop' do
        expect(Karafka.logger).to have_received(:error).with(message).at_least(:once)
      end
    end

    context 'when it is a worker.process.error' do
      let(:type) { 'worker.process.error' }
      let(:message) { "Worker processing failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:fatal).with(message) }
    end

    context 'when it is a app.forceful_stopping.error' do
      let(:type) { 'app.forceful_stopping.error' }
      let(:message) { "Forceful shutdown error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a librdkafka.error' do
      let(:type) { 'librdkafka.error' }
      let(:message) { "librdkafka internal error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a connection.client.poll.error' do
      let(:type) { 'connection.client.poll.error' }
      let(:message) { "Data polling error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a callbacks.statistics.error' do
      let(:type) { 'callbacks.statistics.error' }
      let(:message) { "callbacks.statistics processing failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a callbacks.error.error' do
      let(:type) { 'callbacks.error.error' }
      let(:message) { "callbacks.error processing failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a connection.client.rebalance_callback.error' do
      let(:type) { 'connection.client.rebalance_callback.error' }
      let(:message) { "Rebalance callback error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a connection.client.unsubscribe.error' do
      let(:type) { 'connection.client.unsubscribe.error' }
      let(:message) { "Client unsubscribe error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context 'when it is a different error type' do
      let(:type) { 'different.error' }
      let(:message) { "different.error error occurred: #{error.class} - #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end
  end

  describe '#on_rebalance_partitions_revoked' do
    subject(:trigger) { listener.on_rebalance_partitions_revoked(event) }

    let(:group_id) { 'group1' }
    let(:group_prefix) { "Group #{group_id} rebalance" }

    context 'when no partitions are revoked' do
      let(:payload) do
        {
          tpl: {},
          consumer_group_id: group_id,
          client_id: client_id
        }
      end

      let(:message) { "[#{client_id}] #{group_prefix}: No partitions revoked" }

      it 'expect logger to log that no partitions were revoked' do
        expect(Karafka.logger).to have_received(:info).with(message)
      end
    end

    context 'when partitions are revoked' do
      let(:payload) do
        {
          tpl: {
            'topic1' => [OpenStruct.new(partition: 0), OpenStruct.new(partition: 1)],
            'topic2' => [OpenStruct.new(partition: 0)]
          },
          consumer_group_id: group_id,
          client_id: client_id
        }
      end

      it 'expect logger to log revoked partitions for each topic' do
        expect(Karafka.logger)
          .to have_received(:info)
          .with("[#{client_id}] #{group_prefix}: Partition(s) 0, 1 of topic1 revoked")
        expect(Karafka.logger)
          .to have_received(:info)
          .with("[#{client_id}] #{group_prefix}: Partition(s) 0 of topic2 revoked")
      end
    end
  end

  describe '#on_rebalance_partitions_assigned' do
    subject(:trigger) { listener.on_rebalance_partitions_assigned(event) }

    let(:group_id) { 'group1' }
    let(:group_prefix) { "Group #{group_id} rebalance" }

    context 'when no partitions are assigned' do
      let(:payload) do
        {
          tpl: {},
          consumer_group_id: group_id,
          client_id: client_id
        }
      end

      let(:message) { "[#{client_id}] #{group_prefix}: No partitions assigned" }

      it 'expect logger to log that no partitions were assigned' do
        expect(Karafka.logger).to have_received(:info).with(message)
      end
    end

    context 'when partitions are assigned' do
      let(:payload) do
        {
          tpl: {
            'topic1' => [OpenStruct.new(partition: 0), OpenStruct.new(partition: 1)],
            'topic2' => [OpenStruct.new(partition: 0)]
          },
          consumer_group_id: group_id,
          client_id: client_id
        }
      end

      it 'expect logger to log assigned partitions for each topic' do
        expect(Karafka.logger)
          .to have_received(:info)
          .with("[#{client_id}] #{group_prefix}: Partition(s) 0, 1 of topic1 assigned")

        expect(Karafka.logger)
          .to have_received(:info)
          .with("[#{client_id}] #{group_prefix}: Partition(s) 0 of topic2 assigned")
      end
    end
  end
end
