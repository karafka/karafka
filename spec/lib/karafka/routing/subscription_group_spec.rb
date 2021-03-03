# frozen_string_literal: true

RSpec.describe_current do
  subject(:group) { described_class.new([topic]) }

  let(:topic) { build(:routing_topic, kafka: { 'bootstrap.servers': 'kafka://kafka:9092' }) }

  describe '#id' do
    it { expect(group.id).not_to eq(nil) }
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

  describe '#kafka' do
    it { expect(group.kafka['client.id']).to eq(Karafka::App.config.client_id) }
    it { expect(group.kafka['group.id']).to eq(topic.consumer_group.id) }
    it { expect(group.kafka['auto.offset.reset']).to eq('earliest') }
    it { expect(group.kafka['enable.auto.offset.store']).to eq('false') }
    it { expect(group.kafka['bootstrap.servers']).to eq(topic.kafka['bootstrap.servers']) }
  end
end
