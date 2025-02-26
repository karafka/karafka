# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:consumer_group) { consumer_group_class.new }

  let(:consumer_group_class) do
    Class.new do
      prepend Karafka::Pro::Routing::Features::ParallelSegments::ConsumerGroup

      def name
        "test-group-parallel-1"
      end

      def to_h
        {}
      end
    end
  end

  describe '#parallel_segments' do
    context 'when not previously configured' do
      it 'initializes with default settings' do
        expect(consumer_group.parallel_segments.count).to eq(1)
        expect(consumer_group.parallel_segments.active?).to be false
      end

      it 'sets default merge_key' do
        expect(consumer_group.parallel_segments.merge_key).to eq('-parallel-')
      end

      it 'sets default reducer' do
        expect(consumer_group.parallel_segments.reducer).to be_a(Proc)
      end

      it 'sets default partitioner' do
        expect(consumer_group.parallel_segments.partitioner).to be_nil
      end
    end

    context 'when configured with custom settings' do
      before do
        consumer_group.public_send(
          :parallel_segments=,
          count: 5,
          partitioner: ->(msg) { msg.key },
          reducer: ->(key) { key.hash % 5 },
          merge_key: 'custom-key'
        )
      end

      it 'uses provided count' do
        expect(consumer_group.parallel_segments.count).to eq(5)
      end

      it 'marks as active when count > 1' do
        expect(consumer_group.parallel_segments.active?).to be true
      end

      it 'uses provided merge_key' do
        expect(consumer_group.parallel_segments.merge_key).to eq('custom-key')
      end

      it 'uses provided partitioner' do
        expect(consumer_group.parallel_segments.partitioner).to be_a(Proc)
      end

      it 'uses provided reducer' do
        expect(consumer_group.parallel_segments.reducer).to be_a(Proc)
      end
    end
  end

  describe '#parallel_segments?' do
    context 'when segments count is 1' do
      before { consumer_group.public_send(:parallel_segments=, count: 1) }

      it { expect(consumer_group.parallel_segments?).to be false }
    end

    context 'when segments count is greater than 1' do
      before { consumer_group.public_send(:parallel_segments=, count: 2) }

      it { expect(consumer_group.parallel_segments?).to be true }
    end
  end

  describe '#to_h' do
    before do
      consumer_group.public_send(
        :parallel_segments=,
        count: 3,
        merge_key: 'test-key'
      )
    end

    it 'includes parallel segments configuration' do
      result = consumer_group.to_h
      expect(result).to include(:parallel_segments)
      expect(result).to be_frozen
    end

    it 'serializes parallel segments config correctly' do
      parallel_segments_config = consumer_group.to_h[:parallel_segments]
      expect(parallel_segments_config[:count]).to eq(3)
      expect(parallel_segments_config[:merge_key]).to eq('test-key')
    end
  end

  describe 'default reducer behavior' do
    let(:default_reducer) { consumer_group.parallel_segments.reducer }
    let(:count) { 5 }

    before { consumer_group.public_send(:parallel_segments=, count: count) }

    it 'distributes keys across available segments' do
      results = (1..10).map { |i| default_reducer.call(i) }
      expect(results.uniq.size).to be > 1
      expect(results.all? { |r| r < count }).to be true
    end
  end
end
