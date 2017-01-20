RSpec.describe Karafka::Connection::TopicConsumer do
  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }
  let(:batch_mode) { false }
  let(:route) do
    instance_double(
      Karafka::Routing::Route,
      group: group,
      topic: topic,
      batch_mode: batch_mode
    )
  end

  subject(:topic_consumer) { described_class.new(route) }

  let(:kafka_consumer) { instance_double(Kafka::Consumer, stop: true) }

  describe '.new' do
    it 'just remembers route' do
      expect(topic_consumer.instance_variable_get(:@route)).to eq route
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
      it 'expect to use kafka_consumer to get messages and yield' do
        expect(kafka_consumer).to receive(:each_message).and_yield(incoming_message)
        expect { |block| topic_consumer.fetch_loop(&block) }.to yield_with_args(incoming_message)
      end
    end

    context 'message batch consumption mode' do
      let(:batch_mode) { true }
      let(:incoming_batch) { instance_double(Kafka::FetchedBatch) }
      let(:incoming_messages) { [incoming_message, incoming_message] }

      it 'expect to use kafka_consumer to get messages and yield' do
        expect(kafka_consumer).to receive(:each_batch).and_yield(incoming_batch)
        expect(incoming_batch).to receive(:messages).and_return(incoming_messages)

        expect { |block| topic_consumer.fetch_loop(&block) }
          .to yield_successive_args(*incoming_messages)
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

      before do
        expect(Kafka)
          .to receive(:new)
          .with(
            seed_brokers: ::Karafka::App.config.kafka.hosts,
            logger: ::Karafka.logger,
            client_id: ::Karafka::App.config.name,
            ssl_ca_cert: ::Karafka::App.config.kafka.ssl.ca_cert,
            ssl_client_cert: ::Karafka::App.config.kafka.ssl.client_cert,
            ssl_client_cert_key: ::Karafka::App.config.kafka.ssl.client_cert_key
          )
          .and_return(kafka)
      end

      it 'expect to build it and subscribe' do
        expect(kafka).to receive(:consumer).and_return(consumer)
        expect(consumer).to receive(:subscribe).with(route.topic)
        expect(topic_consumer.send(:kafka_consumer)).to eq consumer
      end
    end
  end
end
