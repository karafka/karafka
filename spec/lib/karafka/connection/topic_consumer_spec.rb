RSpec.describe Karafka::Connection::TopicConsumer do
  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }
  let(:route) do
    instance_double(
      Karafka::Routing::Route,
      group: group,
      topic: topic
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
    it 'expect to stop consumer' do
      expect(topic_consumer)
        .to receive(:kafka_consumer)
        .and_return(kafka_consumer)

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

    it 'expect to use kafka_consumer to get messages and yield' do
      expect(kafka_consumer).to receive(:each_message).and_yield(incoming_message)
      expect { |block| topic_consumer.fetch_loop(&block) }.to yield_control
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
            client_id: ::Karafka::App.config.name
          )
          .and_return(kafka)
      end

      it 'expect to build it and subscribe' do
        expect(kafka).to receive(:consumer).with(group_id: route.group).and_return(consumer)
        expect(consumer).to receive(:subscribe).with(route.topic)
        expect(topic_consumer.send(:kafka_consumer)).to eq consumer
      end
    end
  end
end
