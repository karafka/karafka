# frozen_string_literal: true

RSpec.describe_current do
  let(:topic_name) { "it-#{SecureRandom.uuid}" }

  describe '#describe' do
    subject(:result) { described_class.describe(*resources) }

    context 'when we want to describe only one existing broker' do
      let(:resources) { [described_class::Resource.new(type: :broker, name: '1')] }

      # We check it that way not to may a lot of requests to Kafka
      it do
        expect(result.size).to eq(1)
        expect(result.first.type).to eq(:broker)
        expect(result.first.name).to eq('1')
        expect(result.first.configs.size).to be > 50
        expect(result.first.configs.last.name).to eq('unclean.leader.election.enable')
        expect(result.first.configs.last.value).to eq('false')
        expect(result.first.configs.last.default?).to be(true)
        expect(result.first.configs.last.read_only?).to be(false)
        expect(result.first.configs.last.sensitive?).to be(false)
        expect(result.first.configs.last.synonym?).to be(false)
        expect(result.first.configs.last.synonyms).not_to be_empty
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
        expect(result.first.configs.last.default?).to be(true)
        expect(result.first.configs.last.read_only?).to be(false)
        expect(result.first.configs.last.sensitive?).to be(false)
        expect(result.first.configs.last.synonym?).to be(false)
        expect(result.first.configs.last.synonyms).not_to be_empty
        expect(result.first.configs.last.synonyms.last.synonym?).to be(true)
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

  describe '#alter' do
    subject(:result) do
      result = described_class.alter(*resources)
      # We add 100 ms to make sure that Kafka has time to apply change
      sleep(0.1)
      result
    end

    let(:described_topic_config) do
      lambda do
        Karafka::Admin::Configs.describe(resources).first.configs.find do |config|
          config.name == name
        end.value
      end
    end

    let(:described_broker_config) do
      lambda do
        Karafka::Admin::Configs.describe(resources).first.configs.find do |config|
          config.name == name
        end.value
      end
    end

    before { Karafka::Admin.create_topic(topic_name, 2, 1) }

    context 'when there is nothing to alter in a resource' do
      let(:resources) { [described_class::Resource.new(type: :broker, name: '1')] }

      it { expect(result.size).to eq(1) }
    end

    context 'when we want to set a valid value on a topic' do
      let(:name) { 'delete.retention.ms' }
      let(:value) { rand(86_400_001..86_800_000).to_s }
      let(:resources) { [described_class::Resource.new(type: :topic, name: topic_name)] }

      before { resources.first.set(name, value) }

      it { expect { result }.to change(described_topic_config, :call).from('86400000').to(value) }
    end

    context 'when we want to set an invalid value on a topic' do
      let(:name) { 'delete.retention.ms' }
      let(:value) { '-100' }
      let(:resources) { [described_class::Resource.new(type: :topic, name: topic_name)] }

      before { resources.first.set(name, value) }

      it { expect { result }.to raise_error(Rdkafka::RdkafkaError, /invalid_config/) }
    end

    context 'when we want to delete a predefined value on a topic' do
      let(:name) { 'delete.retention.ms' }
      let(:value) { nil }
      let(:resources) { [described_class::Resource.new(type: :topic, name: topic_name)] }

      before do
        setter = described_class::Resource.new(type: :topic, name: topic_name)
        setter.set(name, 100_000)
        described_class.alter(setter)

        resources.first.delete(name)
      end

      it 'expect to reset to cluster default' do
        expect { result }.to change(described_topic_config, :call).from('100000').to('86400000')
      end
    end

    context 'when we want to append to a topic' do
      let(:name) { 'cleanup.policy' }
      let(:value) { 'compact' }
      let(:resources) { [described_class::Resource.new(type: :topic, name: topic_name)] }

      before do
        setter = described_class::Resource.new(type: :topic, name: topic_name)
        setter.set(name, 'delete')
        described_class.alter(setter)

        resources.first.append(name, value)
      end

      it 'expect to append to the previous' do
        expect { result }
          .to change(described_topic_config, :call)
          .from('delete').to('delete,compact')
      end
    end

    context 'when we want to both delete and set multiple settings' do
      let(:resources) { [described_class::Resource.new(type: :topic, name: topic_name)] }

      before do
        resources.first.set('cleanup.policy', 'compact')
        resources.first.delete('delete.retention.ms')
      end

      it { expect { result }.not_to raise_error }
    end

    context 'when we want to operate on few resources' do
      let(:resources) do
        [
          described_class::Resource.new(type: :topic, name: topic_name),
          described_class::Resource.new(type: :topic, name: "#{topic_name}2")
        ]
      end

      before do
        Karafka::Admin.create_topic("#{topic_name}2", 2, 1)
        resources.first.set('cleanup.policy', 'compact')
        resources.last.delete('delete.retention.ms')
      end

      it { expect { result }.not_to raise_error }
    end

    context 'when we want to subtract from a topic' do
      let(:name) { 'cleanup.policy' }
      let(:value) { 'compact' }
      let(:resources) { [described_class::Resource.new(type: :topic, name: topic_name)] }

      before do
        setter = described_class::Resource.new(type: :topic, name: topic_name)
        setter.set(name, 'delete,compact')
        described_class.alter(setter)

        resources.first.delete(name, value)
      end

      it 'expect to delete from the config value' do
        expect { result }
          .to change(described_topic_config, :call)
          .from('delete,compact').to('delete')
      end
    end

    context 'when we want to set a valid value on a broker' do
      let(:name) { 'background.threads' }
      let(:broker_name) { '1' }
      let(:value) { (threads_before.to_i + 1).to_s }
      let(:resources) { [described_class::Resource.new(type: :broker, name: broker_name)] }
      let(:threads_before) { described_broker_config.call }

      before do
        resources.first.set(name, value)
        threads_before
      end

      it 'expect to be able to alter broker settings' do
        expect { result }
          .to change(described_topic_config, :call)
          .from(threads_before.to_s)
          .to((threads_before.to_i + 1).to_s)
      end
    end
  end
end
