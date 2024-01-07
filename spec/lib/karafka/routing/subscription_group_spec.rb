# frozen_string_literal: true

RSpec.describe_current do
  subject(:group) { described_class.new(0, topics) }

  let(:topic) { build(:routing_topic, kafka: { 'bootstrap.servers': 'kafka://kafka:9092' }) }
  let(:topics) { [topic] }

  describe '#id' do
    it { expect(group.id).to eq("#{topic.consumer_group.id}_#{topic.subscription_group_name}_0") }
  end

  describe '#to_s' do
    it { expect(group.to_s).to eq(group.id) }
  end

  describe '#max_messages' do
    it { expect(group.max_messages).to eq(topic.max_messages) }
  end

  describe '#max_wait_time' do
    it { expect(group.max_wait_time).to eq(topic.max_wait_time) }
  end

  describe '#topics' do
    it { expect(group.topics).to eq([topic]) }
  end

  describe '#consumer_group' do
    it { expect(group.consumer_group).to eq(topic.consumer_group) }
  end

  describe '#subscriptions' do
    it { expect(group.subscriptions).to eq([topic.name]) }

    context 'when there are inactive topics in given group' do
      let(:topic2) { build(:routing_topic).tap { |top| top.active(false) } }

      before { topics << topic2 }

      it 'expect not to include inactive topics' do
        expect(group.subscriptions).to eq([topic.name])
      end
    end
  end

  describe '#family' do
    it { expect(group.family).to eq("#{group.consumer_group.id}_#{group.name}") }

    context 'when we have two groups handling same topics in the same consumer group' do
      let(:group1) { described_class.new(0, topics) }
      let(:group2) { described_class.new(1, topics) }

      it { expect(group1.family).to eq(group2.family) }
    end
  end

  describe '#consumer_group_id' do
    it { expect(group.consumer_group_id).to eq(topic.consumer_group.id) }
  end

  describe '#kafka' do
    it { expect(group.kafka[:'client.id']).to eq(Karafka::App.config.client_id) }
    it { expect(group.kafka[:'auto.offset.reset']).to eq('earliest') }
    it { expect(group.kafka[:'enable.auto.offset.store']).to eq(false) }
    it { expect(group.kafka[:'bootstrap.servers']).to eq(topic.kafka[:'bootstrap.servers']) }
  end

  describe '#active?' do
    context 'when there are no topics in the subscription group' do
      it { expect(group.active?).to eq true }
    end

    context 'when our subscription group name is in server subscription groups' do
      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:subscription_groups, topic.subscription_group_name)
      end

      it { expect(group.active?).to eq true }
    end

    context 'when our subscription group name is not in server subscription groups' do
      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:subscription_groups, 'na')
      end

      it { expect(group.active?).to eq false }
    end
  end
end
