# frozen_string_literal: true

require "karafka/instrumentation/vendors/prometheus_exporter/metrics_listener"
require 'prometheus_exporter'
require 'prometheus_exporter/server'

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:event) { Karafka::Core::Monitoring::Event.new(rand.to_s, payload) }
  let(:time) { rand }
  let(:topic) { build(:routing_topic, name: topic_name) }
  let(:topic_name) { rand.to_s }

  before do
    allow(listener.client).to receive(:send_json)
    trigger
  end

  shared_examples 'a metrics listener' do
    let(:metric_payload) { { type: "karafka", payload: metrics } }

    it 'sends metrics to the prometheus exporter server' do
      expect(listener.client).to have_received(:send_json).with(metric_payload)
    end
  end

  describe '#on_connection_listener_fetch_loop_received' do
    subject(:trigger) { listener.on_connection_listener_fetch_loop_received(event) }
    let(:connection_listener) { instance_double(Karafka::Connection::Listener, id: 'id') }
    let(:subscription_group) { instance_double(Karafka::Routing::SubscriptionGroup, consumer_group_id: rand(10)) }

    context 'when there are no messages polled' do
      let(:payload) do
        {
          caller: connection_listener,
          subscription_group: subscription_group,
          messages_buffer: [{},{}],
          time: 2
        }
      end
      let(:metrics) do
        labels = {consumer_group: event.payload[:subscription_group].consumer_group_id}
        {
          listener_polling_messages: [
            event.payload[:messages_buffer].size,
            labels
          ],
          listener_polling_time_seconds: [
            event.payload[:time] / 1_000.0, # expect seconds not ms
            labels
          ]
        }
      end

      it_behaves_like 'a metrics listener'
    end
  end

  describe '#on_worker_process' do
    subject(:trigger) { listener.on_worker_process(event) }
    let(:stats) { { busy: 1, enqueued: 1 } }
    let(:jobs_queue) { instance_double(Karafka::Processing::JobsQueue, statistics: stats) }
    let(:payload) { { jobs_queue: jobs_queue } }
    let(:metrics) do
      {
        worker_threads: [Karafka::App.config.concurrency, {}],
        worker_threads_busy: [stats[:busy], {}],
        worker_enqueued_jobs: [stats[:enqueued], {}]
      }
    end

    it_behaves_like 'a metrics listener'
  end

  describe '#on_worker_processed' do
    subject(:trigger) { listener.on_worker_processed(event) }
    let(:stats) { { busy: 1, enqueued: 1 } }
    let(:jobs_queue) { instance_double(Karafka::Processing::JobsQueue, statistics: stats) }
    let(:payload) { { jobs_queue: jobs_queue } }
    let(:metrics) do
      {
        worker_threads_busy: [stats[:busy], {}],
      }
    end

    it_behaves_like 'a metrics listener'
  end

  describe '#on_app_stopped' do
    subject(:trigger) { listener.on_app_stopped(event) }

    let(:payload) { {} }
    let(:metrics) {  {app_stopped_total: [1, {}]} }

    it_behaves_like 'a metrics listener'
  end

  describe '#on_dead_letter_queue_dispatched' do
    subject(:trigger) { listener.on_dead_letter_queue_dispatched(event) }

    let(:topic) { build(:routing_topic, name: 'test') }
    let(:coordinator) { create(:processing_coordinator, topic: topic) }
    let(:consumer) do
      instance = Class.new(Karafka::BaseConsumer).new
      instance.coordinator = coordinator
      instance.messages = messages
      topic.dead_letter_queue(topic: 'dlq')
      instance
    end
    let(:messages) do
      instance_double(
        Karafka::Messages::Messages,
        metadata: Karafka::Messages::BatchMetadata.new(
          topic: topic.name,
          partition: 0,
          processed_at: Time.now
        )
      )
    end
    let(:payload) { { caller: consumer, messages: messages } }
    let(:labels) do
      {
        dead_letter_queue_topic: event[:caller].topic.dead_letter_queue.topic,
        consumer_group: consumer.topic.consumer_group.id,
        partition: event[:caller].messages.metadata.partition,
        topic: event[:caller].topic.name,
      }
    end
    let(:metrics) { { dead_letter_queue_total: [1, labels] } }

    it_behaves_like 'a metrics listener'
  end

  describe '#on_error_occurred' do
    subject(:trigger) { listener.on_error_occurred(event) }

    let(:error) { StandardError.new }
    let(:payload) { { caller: caller, error: error, type: type } }
    let(:metrics) { { consumer_error_total: [1, { type: type }]} }

    context 'when a consumer with messages errors' do
      let(:type) { 'consumer.consume.error' }
      let(:coordinator) { create(:processing_coordinator, topic: topic) }
      let(:caller) do
        instance = Class.new(Karafka::BaseConsumer).new
        instance.coordinator = coordinator
        instance.messages = messages
        topic.dead_letter_queue(topic: 'dlq')
        instance
      end
      let(:messages) do
        instance_double(
          Karafka::Messages::Messages,
          metadata: Karafka::Messages::BatchMetadata.new(
            topic: topic.name,
            partition: 0,
            processed_at: Time.now
          )
        )
      end
      let(:labels) do
        {
          consumer_group: caller.topic.consumer_group.id,
          partition: event[:caller].messages.metadata.partition,
          topic: event[:caller].topic.name,
          type: type
        }
      end
      let(:metrics) { { consumer_error_total: [1, labels]} }


      it_behaves_like 'a metrics listener'
    end

    context 'when it is a connection.listener.fetch_loop.error' do
      let(:type) { 'connection.listener.fetch_loop.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a consumer.consume.error' do
      let(:type) { 'consumer.consume.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a consumer.revoked.error' do
      let(:type) { 'consumer.revoked.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a consumer.before_enqueue.error' do
      let(:type) { 'consumer.before_enqueue.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a consumer.before_consume.error' do
      let(:type) { 'consumer.before_consume.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a consumer.after_consume.error' do
      let(:type) { 'consumer.after_consume.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a consumer.idle.error' do
      let(:type) { 'consumer.idle.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a consumer.shutdown.error' do
      let(:type) { 'consumer.shutdown.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a runner.call.error' do
      let(:type) { 'runner.call.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is an app.stopping.error' do
      let(:type) { 'app.stopping.error' }
      let(:payload) { { type: type, error: Karafka::Errors::ForcefulShutdownError.new } }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a worker.process.error' do
      let(:type) { 'worker.process.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a librdkafka.error' do
      let(:type) { 'librdkafka.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a connection.client.poll.error' do
      let(:type) { 'connection.client.poll.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is a statistics.emitted.error' do
      let(:type) { 'statistics.emitted.error' }

      it_behaves_like 'a metrics listener'
    end

    context 'when it is an unsupported error type' do
      let(:type) { 'unsupported.error' }

      it_behaves_like 'a metrics listener'
    end
  end
end
