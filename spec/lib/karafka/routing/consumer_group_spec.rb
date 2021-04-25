# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer_group) { described_class.new(name) }

  let(:name) { rand.to_s }

  describe 'after initialize' do
    it 'expect not to have any topics yet' do
      expect(consumer_group.topics).to be_empty
    end
  end

  describe '#id' do
    it 'expect to namespace id with application client_id' do
      old_client_id = Karafka::App.config.client_id
      Karafka::App.config.client_id = 'ExampleClient'

      consumer_group = described_class.new('consumers')
      expect(consumer_group.id).to eq('example_client_consumers')

      Karafka::App.config.client_id = old_client_id
    end
  end

  %w[
    kafka
    deserializer
    max_messages
    max_wait_time
  ].each do |attribute|
    context attribute.to_s do
      it 'by default expect to fallback to a kafka config value' do
        expected_config_value = Karafka::App.config.public_send(attribute)
        expect(consumer_group.public_send(attribute)).to eq expected_config_value
      end
    end
  end

  describe '#topic=' do
    let(:built_topic) do
      # assigning block to a "=" method does not work normally
      consumer_group.public_send(:topic=, :topic_name) do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end

    before { built_topic }

    it { expect(consumer_group.topics.count).to eq 1 }
    it { expect(built_topic.name).to eq :topic_name.to_s }
  end

  describe '#subscription_groups' do
    context 'when there are not topics defined' do
      it { expect(consumer_group.subscription_groups).to eq([]) }
    end

    context 'when there are some topics defined' do
      let(:subscription_group) { consumer_group.subscription_groups.first }
      let(:built_topic) do
        consumer_group.public_send(:topic=, :topic_name) do
          consumer Class.new(Karafka::BaseConsumer)
        end
      end

      before { built_topic }

      it { expect(subscription_group).to be_a(Karafka::Routing::SubscriptionGroup) }
    end
  end

  describe '#active?' do
    context 'when there are no topics in the consumer group' do
      it { expect(consumer_group.active?).to eq false }
    end

    context 'when none of the topics is active' do
      before do
        consumer_group.public_send(:topic=, :topic_name) do
          consumer Class.new(Karafka::BaseConsumer)
        end
      end

      it { expect(consumer_group.active?).to eq false }
    end

    context 'when our consumer group name is in server consumer groups' do
      before { Karafka::Server.consumer_groups = [name] }

      it { expect(consumer_group.active?).to eq true }
    end
  end

  describe '#to_h' do
    let(:casted_consumer_group) { consumer_group.to_h }

    %w[
      kafka
      deserializer
      max_messages
      max_wait_time
    ].each do |cg_attribute|
      it { expect(casted_consumer_group.keys).to include(cg_attribute) }
    end

    it { expect(casted_consumer_group.keys).to include(:topics) }
    it { expect(casted_consumer_group.keys).to include(:id) }

    context 'when there are topics inside' do
      let(:built_topic) do
        consumer_group.public_send(:topic=, :topic_name) do
          consumer Class.new(Karafka::BaseConsumer)
        end
      end

      before { built_topic }

      it 'expect to have them casted to hash as well' do
        expect(casted_consumer_group[:topics].first).to eq built_topic.to_h
      end
    end
  end
end
