# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#declaratives' do
    context 'when we use declaratives without any arguments without config exec' do
      it { expect(topic.declaratives.active?).to eq(true) }
      it { expect(topic.declaratives.partitions).to eq(1) }
      it { expect(topic.declaratives.replication_factor).to eq(1) }
      it { expect(topic.declaratives.details).to eq({}) }
    end

    context 'when we use declaratives with custom number of partitions' do
      before { topic.config(partitions: 5) }

      it { expect(topic.declaratives.partitions).to eq(5) }
    end

    context 'when we use declaratives with custom replication factor' do
      before { topic.config(replication_factor: 5) }

      it { expect(topic.declaratives.replication_factor).to eq(5) }
    end

    context 'when we use declaratives with other custom settings' do
      before { topic.config('cleanup.policy': 'compact') }

      it { expect(topic.declaratives.details[:'cleanup.policy']).to eq('compact') }
    end
  end

  describe '#declaratives?' do
    it 'expect to always be active' do
      expect(topic.declaratives?).to eq(true)
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:declaratives]).to eq(topic.declaratives.to_h) }
  end
end
