# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#structurable' do
    context 'when we use structurable without any arguments without config exec' do
      it { expect(topic.structurable.active?).to eq(true) }
      it { expect(topic.structurable.partitions).to eq(1) }
      it { expect(topic.structurable.replication_factor).to eq(1) }
      it { expect(topic.structurable.details).to eq({}) }
    end

    context 'when we use structurable with custom number of partitions' do
      before { topic.config(partitions: 5) }

      it { expect(topic.structurable.partitions).to eq(5) }
    end

    context 'when we use structurable with custom replication factor' do
      before { topic.config(replication_factor: 5) }

      it { expect(topic.structurable.replication_factor).to eq(5) }
    end

    context 'when we use structurable with other custom settings' do
      before { topic.config('cleanup.policy': 'compact') }

      it { expect(topic.structurable.details[:'cleanup.policy']).to eq('compact') }
    end
  end

  describe '#structurable?' do
    it 'expect to always be active' do
      expect(topic.structurable?).to eq(true)
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:structurable]).to eq(topic.structurable.to_h) }
  end
end
