# frozen_string_literal: true

RSpec.describe Karafka::Connection::Client do
  subject(:client) { described_class.new(consumer_group) }

  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }
  let(:partition) { rand(100) }
  let(:batch_fetching) { false }
  let(:start_from_beginning) { false }
  let(:kafka_consumer) { instance_double(Kafka::Consumer, stop: true, pause: true) }
  let(:consumer_group) do
    batch_fetching_active = batch_fetching
    start_from_beginning_active = start_from_beginning
    Karafka::Routing::ConsumerGroup.new(group).tap do |cg|
      cg.batch_fetching = batch_fetching_active

      cg.public_send(:topic=, topic) do
        consumer Class.new(Karafka::BaseConsumer)
        backend :inline
        start_from_beginning start_from_beginning_active
      end
    end
  end

  before do
    Karafka::Server.consumer_groups = [group]
  end

  describe '.new' do
    it 'just remembers consumer_group' do
      expect(client.instance_variable_get(:@consumer_group)).to eq consumer_group
    end
  end

  describe '#stop' do
    before { client.instance_variable_set(:'@kafka_consumer', kafka_consumer) }

    it 'expect to stop consumer' do
      expect(kafka_consumer)
        .to receive(:stop)

      client.stop
    end

    it 'expect to remove kafka_consumer' do
      client.instance_variable_set(:'@kafka_consumer', kafka_consumer)
      client.stop
      expect(client.instance_variable_get(:'@kafka_consumer')).to eq nil
    end
  end

  describe '#pause' do
    before do
      client.instance_variable_set(:'@kafka_consumer', kafka_consumer)
      allow(consumer_group).to receive(:pause_timeout).and_return(pause_timeout)
    end

    context 'when pause_timeout is set to 0' do
      let(:pause_timeout) { 0 }
      let(:error) { Karafka::Errors::InvalidPauseTimeout }

      it 'expect to raise an exception' do
        expect(kafka_consumer).not_to receive(:pause)
        expect { client.send(:pause, topic, partition) }.to raise_error(error)
      end
    end

    context 'when pause_timeout is not set to 0' do
      let(:pause_timeout) { rand(1..100) }

      it 'expect not to pause consumer_group' do
        expect(kafka_consumer).to receive(:pause).with(topic, partition, timeout: pause_timeout)
        expect(client.send(:pause, topic, partition)).to eq true
      end
    end
  end

  describe '#mark_as_consumed' do
    let(:params) { instance_double(Karafka::Params::Params) }

    before { client.instance_variable_set(:'@kafka_consumer', kafka_consumer) }

    it 'expect to forward to mark_message_as_processed and commit offsets' do
      expect(kafka_consumer).to receive(:mark_message_as_processed).with(params)
      expect(kafka_consumer).to receive(:commit_offsets)
      client.mark_as_consumed(params)
    end
  end

  describe '#fetch_loop' do
    let(:incoming_message) { rand }

    before { client.instance_variable_set(:'@kafka_consumer', kafka_consumer) }

    context 'when everything works smooth' do
      context 'with single message consumption mode' do
        let(:messages) { [incoming_message] }

        it 'expect to use kafka_consumer to get each message and yield as an array of messages' do
          expect(kafka_consumer).to receive(:each_message).and_yield(incoming_message)
          expect { |block| client.fetch_loop(&block) }.to yield_with_args(messages)
        end
      end

      context 'with message batch consumption mode' do
        let(:batch_fetching) { true }
        let(:incoming_batch) { instance_double(Kafka::FetchedBatch) }
        let(:incoming_messages) { [incoming_message, incoming_message] }

        it 'expect to use kafka_consumer to get messages and yield all of them' do
          expect(kafka_consumer).to receive(:each_batch).and_yield(incoming_batch)
          expect(incoming_batch).to receive(:messages).and_return(incoming_messages)

          expect { |block| client.fetch_loop(&block) }
            .to yield_successive_args(incoming_messages)
        end
      end
    end

    context 'when Kafka::ProcessingError occurs' do
      let(:error) do
        Kafka::ProcessingError.new(
          topic,
          partition,
          cause: StandardError.new
        )
      end

      before do
        count = 0
        allow(kafka_consumer).to receive(:each_message).exactly(2).times do
          count += 1
          count == 1 ? raise(error) : true
        end

        # Lets silence exceptions printing
        allow(Karafka.monitor)
          .to receive(:notice_error)
          .with(described_class, error.cause)
      end

      it 'notice, pause and not reraise error' do
        expect(kafka_consumer).to receive(:pause).and_return(true)
        expect { client.fetch_loop {} }.not_to raise_error
      end
    end

    context 'when no consuming error' do
      let(:error) { Exception.new }

      before do
        count = 0
        allow(kafka_consumer).to receive(:each_message).exactly(2).times do
          count += 1
          count == 1 ? raise(error) : true
        end

        # Lets silence exceptions printing
        allow(Karafka.monitor)
          .to receive(:notice_error)
          .with(described_class, error)
      end

      it 'notices and not reraise error' do
        expect(kafka_consumer).not_to receive(:pause)
        expect { client.fetch_loop {} }.not_to raise_error
      end
    end
  end

  describe '#kafka_consumer' do
    context 'when kafka_consumer is already built' do
      before { client.instance_variable_set(:'@kafka_consumer', kafka_consumer) }

      it 'expect to return it' do
        expect(client.send(:kafka_consumer)).to eq kafka_consumer
      end
    end

    context 'when kafka_consumer is not yet built' do
      let(:kafka) { instance_double(Kafka::Client) }
      let(:kafka_consumer) { instance_double(Kafka::Consumer) }
      let(:subscribe_params) do
        [
          consumer_group.topics.first.name,
          start_from_beginning: start_from_beginning,
          max_bytes_per_partition: 1_048_576
        ]
      end

      before do
        allow(Kafka)
          .to receive(:new)
          .with(
            ::Karafka::App.config.kafka.seed_brokers,
            logger: ::Karafka.logger,
            client_id: ::Karafka::App.config.client_id,
            socket_timeout: 30,
            connect_timeout: 10,
            sasl_plain_authzid: '',
            ssl_ca_certs_from_system: false
          )
          .and_return(kafka)
      end

      it 'expect to build it and subscribe' do
        expect(kafka).to receive(:consumer).and_return(kafka_consumer)
        expect(kafka_consumer).to receive(:subscribe).with(*subscribe_params)
        expect(client.send(:kafka_consumer)).to eq kafka_consumer
      end
    end

    context 'when there was a kafka connection failure' do
      before do
        client.instance_variable_set(:'@kafka_consumer', nil)

        expect(Kafka).to receive(:new).and_raise(Kafka::ConnectionError)
      end

      it 'expect to sleep and reraise' do
        expect(client).to receive(:sleep).with(5)

        expect { client.send(:kafka_consumer) }.to raise_error(Kafka::ConnectionError)
      end
    end
  end
end
