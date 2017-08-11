# frozen_string_literal: true

RSpec.describe Karafka::Connection::MessagesConsumer do
  subject(:topic_consumer) { described_class.new(consumer_group) }

  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }
  let(:batch_consuming) { false }
  let(:start_from_beginning) { false }
  let(:kafka_consumer) { instance_double(Kafka::Consumer, stop: true) }
  let(:consumer_group) do
    batch_consuming_active = batch_consuming
    start_from_beginning_active = start_from_beginning
    Karafka::Routing::ConsumerGroup.new(group).tap do |cg|
      cg.batch_consuming = batch_consuming_active

      cg.public_send(:topic=, topic) do
        controller Class.new
        inline_processing true
        start_from_beginning start_from_beginning_active
      end
    end
  end

  describe '.new' do
    it 'just remembers consumer_group' do
      expect(topic_consumer.instance_variable_get(:@consumer_group)).to eq consumer_group
    end
  end

  describe '#stop' do
    before { topic_consumer.instance_variable_set(:'@kafka_consumer', kafka_consumer) }

    it 'expect to stop consumer' do
      expect(kafka_consumer)
        .to receive(:stop)

      topic_consumer.stop
    end

    it 'expect to remove kafka_consumer' do
      topic_consumer.instance_variable_set(:'@kafka_consumer', kafka_consumer)
      topic_consumer.stop
      expect(topic_consumer.instance_variable_get(:'@kafka_consumer')).to eq nil
    end
  end

  describe '#fetch_loop' do
    let(:incoming_message) { rand }

    before { topic_consumer.instance_variable_set(:'@kafka_consumer', kafka_consumer) }

    context 'single message consumption mode' do
      it 'expect to use kafka_consumer to get each message and yield as an array of messages' do
        expect(kafka_consumer).to receive(:each_message).and_yield(incoming_message)
        expect { |block| topic_consumer.fetch_loop(&block) }.to yield_with_args([incoming_message])
      end
    end

    context 'message batch consumption mode' do
      let(:batch_consuming) { true }
      let(:incoming_batch) { instance_double(Kafka::FetchedBatch) }
      let(:incoming_messages) { [incoming_message, incoming_message] }

      it 'expect to use kafka_consumer to get messages and yield all of them' do
        expect(kafka_consumer).to receive(:each_batch).and_yield(incoming_batch)
        expect(incoming_batch).to receive(:messages).and_return(incoming_messages)

        expect { |block| topic_consumer.fetch_loop(&block) }
          .to yield_successive_args(incoming_messages)
      end
    end
  end

  describe '#kafka_consumer' do
    context 'when kafka_consumer is already built' do
      before { topic_consumer.instance_variable_set(:'@kafka_consumer', kafka_consumer) }

      it 'expect to return it' do
        expect(topic_consumer.send(:kafka_consumer)).to eq kafka_consumer
      end
    end

    context 'when kafka_consumer is not yet built' do
      let(:kafka) { instance_double(Kafka::Client) }
      let(:consumer) { instance_double(Kafka::Consumer) }
      let(:subscribe_params) do
        [
          consumer_group.topics.first.name,
          start_from_beginning: start_from_beginning,
          max_bytes_per_partition: 1_048_576
        ]
      end

      before do
        expect(Kafka)
          .to receive(:new)
          .with(
            logger: ::Karafka.logger,
            client_id: ::Karafka::App.config.client_id,
            seed_brokers: ::Karafka::App.config.kafka.seed_brokers,
            socket_timeout: 10,
            connect_timeout: 10,
            sasl_plain_authzid: ''
          )
          .and_return(kafka)
      end

      it 'expect to build it and subscribe' do
        expect(kafka).to receive(:consumer).and_return(consumer)
        expect(consumer).to receive(:subscribe).with(*subscribe_params)
        expect(topic_consumer.send(:kafka_consumer)).to eq consumer
      end
    end

    context 'when there was a kafka connection failure' do
      before do
        topic_consumer.instance_variable_set(:'@kafka_consumer', nil)

        expect(Kafka).to receive(:new).and_raise(Kafka::ConnectionError)
      end

      it 'expect to sleep and reraise' do
        expect(topic_consumer).to receive(:sleep).with(5)

        expect { topic_consumer.send(:kafka_consumer) }.to raise_error(Kafka::ConnectionError)
      end
    end
  end
end
