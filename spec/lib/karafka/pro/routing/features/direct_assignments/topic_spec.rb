# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#direct_assignments' do
    context 'when initialized without arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.direct_assignments.active).to be(false)
      end
    end

    context 'when initialized with specific partitions' do
      let(:partitions) { [1, 2, 3] }

      it 'expect to mark as active and use given partitions' do
        topic.direct_assignments(*partitions)
        expect(topic.direct_assignments.active).to be(true)
        expect(topic.direct_assignments.partitions).to eq(partitions.map { |p| [p, true] }.to_h)
      end
    end

    context 'when initialized with true' do
      it 'expect to use all partitions' do
        topic.direct_assignments(true)
        expect(topic.direct_assignments.active).to be(true)
        expect(topic.direct_assignments.partitions).to be(true)
      end
    end

    context 'when initialized with range of partitions' do
      let(:partitions) { (1..3) }

      it 'expect to mark as active and use given partitions' do
        topic.direct_assignments(partitions)
        expect(topic.direct_assignments.active).to be(true)
        expect(topic.direct_assignments.partitions).to eq(partitions.map { |p| [p, true] }.to_h)
      end
    end
  end

  describe '#to_h' do
    context 'when direct assignments are active' do
      before { topic.direct_assignments(1, 2, 3) }

      it { expect(topic.to_h[:direct_assignments]).to eq(topic.direct_assignments.to_h) }
    end

    context 'when direct assignments are not active' do
      before { topic.direct_assignments }

      it { expect(topic.to_h[:direct_assignments]).to eq(topic.direct_assignments.to_h) }
    end
  end
end
