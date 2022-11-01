# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#virtual_partitions' do
    context 'when we use virtual_partitions without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.virtual_partitions.active?).to eq(false)
        expect(topic.virtual_partitions.partitioner).to eq(nil)
        expect(topic.virtual_partitions.max_partitions).to eq(Karafka::App.config.concurrency)
      end
    end

    context 'when we define partitioner only' do
      it 'expect to use proper active status' do
        topic.virtual_partitions(partitioner: ->(_) { rand })
        expect(topic.virtual_partitions.active?).to eq(true)
        expect(topic.virtual_partitions.max_partitions).to eq(Karafka::App.config.concurrency)
      end
    end

    context 'when we define partitioner and max_partitions' do
      it 'expect to use proper active status' do
        topic.virtual_partitions(partitioner: ->(_) { rand }, max_partitions: 7)
        expect(topic.virtual_partitions.active?).to eq(true)
        expect(topic.virtual_partitions.max_partitions).to eq(7)
      end
    end
  end

  describe '#virtual_partitions?' do
    context 'when active' do
      before { topic.virtual_partitions(partitioner: ->(_) { rand }) }

      it { expect(topic.virtual_partitions?).to eq(true) }
    end

    context 'when not active' do
      before { topic.virtual_partitions(partitioner: nil) }

      it { expect(topic.virtual_partitions?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:virtual_partitions]).to eq(topic.virtual_partitions.to_h) }
  end
end
