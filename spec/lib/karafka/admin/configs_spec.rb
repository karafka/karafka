# frozen_string_literal: true

RSpec.describe_current do
  describe '#describe' do
    subject(:result) { described_class.describe(*resources) }

    let(:topic_name) { SecureRandom.uuid }

    context 'when we want to describe only one existing broker' do
      let(:resources) { [described_class::Resource.new(type: :broker, name: '1')] }

      # We check it that way not to may a lot of requests to Kafka
      it do
        expect(result.size).to eq(1)
        expect(result.first.type).to eq(:broker)
        expect(result.first.name).to eq('1')
        expect(result.first.configs.size).to be > 50
        expect(result.first.configs.last.name).to eq('zookeeper.ssl.truststore.type')
        expect(result.first.configs.last.value).to eq(nil)
        expect(result.first.configs.last.default?).to eq(true)
        expect(result.first.configs.last.read_only?).to eq(true)
        expect(result.first.configs.last.sensitive?).to eq(false)
        expect(result.first.configs.last.synonym?).to eq(false)
        expect(result.first.configs.last.synonyms).to be_empty
      end
    end

    context 'when we want to describe only one existing topic' do
      let(:resources) { [described_class::Resource.new(type: :topic, name: topic_name)] }

      before { Karafka::Admin.create_topic(topic_name, 2, 1) }

      # We check it that way not to may a lot of requests to Kafka and not to create several
      # topics just to run those specs
      it do
        expect(result.size).to eq(1)
        expect(result.first.type).to eq(:topic)
        expect(result.first.name).to eq(topic_name)
        expect(result.first.configs.size).to be > 20
        expect(result.first.configs.last.name).to eq('unclean.leader.election.enable')
        expect(result.first.configs.last.value).to eq('false')
        expect(result.first.configs.last.default?).to eq(true)
        expect(result.first.configs.last.read_only?).to eq(false)
        expect(result.first.configs.last.sensitive?).to eq(false)
        expect(result.first.configs.last.synonym?).to eq(false)
        expect(result.first.configs.last.synonyms).not_to be_empty
        expect(result.first.configs.last.synonyms.last.synonym?).to eq(true)
      end
    end

    context 'when we want to describe non-existing topic' do
      let(:resources) { [described_class::Resource.new(type: :topic, name: SecureRandom.uuid)] }

      it 'expect to raise error' do
        expect { result }.to raise_error(Rdkafka::RdkafkaError, /unknown_topic_or_part/)
      end
    end

    context 'when trying to describe existing and non-existing resources' do
      before { Karafka::Admin.create_topic(topic_name, 2, 1) }

      let(:resources) do
        [
          described_class::Resource.new(type: :topic, name: topic_name),
          described_class::Resource.new(type: :topic, name: SecureRandom.uuid)
        ]
      end

      it 'expect to raise error' do
        expect { result }.to raise_error(Rdkafka::RdkafkaError, /unknown_topic_or_part/)
      end
    end

    context 'when trying to query multiple brokers at the same time' do
      let(:resources) do
        [
          described_class::Resource.new(type: :broker, name: '1'),
          described_class::Resource.new(type: :broker, name: '2')
        ]
      end

      it 'expect to raise error' do
        expect { result }.to raise_error(Rdkafka::RdkafkaError, /conflict/)
      end
    end
  end
end
