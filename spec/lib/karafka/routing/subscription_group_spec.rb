# frozen_string_literal: true

RSpec.describe_current do
  subject(:group) { described_class.new(0, [topic]) }

  let(:topic) { build(:routing_topic, kafka: { 'bootstrap.servers': 'kafka://kafka:9092' }) }

  describe '#id' do
    it { expect(group.id).to eq("#{topic.subscription_group}_0") }
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

  describe '#kafka' do
    it { expect(group.kafka[:'client.id']).to eq(Karafka::App.config.client_id) }
    it { expect(group.kafka[:'auto.offset.reset']).to eq('earliest') }
    it { expect(group.kafka[:'enable.auto.offset.store']).to eq(false) }
    it { expect(group.kafka[:'bootstrap.servers']).to eq(topic.kafka[:'bootstrap.servers']) }
  end

  describe '#active?' do
    context 'when there are no topics in the subscription group' do
      before { Karafka::App.config.internal.routing.active.subscription_groups = [] }

      it { expect(group.active?).to eq true }
    end

    context 'when our subscription group name is in server subscription groups' do
      before do
        Karafka::App.config.internal.routing.active.subscription_groups = [
          topic.subscription_group
        ]
      end

      it { expect(group.active?).to eq true }
    end

    context 'when our subscription group name is not in server subscription groups' do
      before { Karafka::App.config.internal.routing.active.subscription_groups = ['na'] }

      it { expect(group.active?).to eq false }
    end
  end
end
