# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:consumer_group) { consumer_group_class.new }

  let(:consumer_group_class) do
    Class.new do
      prepend Karafka::Pro::Routing::Features::ParallelSegments::ConsumerGroup

      def name
        'test-group-parallel-1'
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

  describe '#segment_id' do
    context 'when parallel segments are not active' do
      before { consumer_group.public_send(:parallel_segments=, count: 1) }

      it 'returns nil' do
        expect(consumer_group.segment_id).to eq(-1)
      end
    end

    context 'when parallel segments are active' do
      before do
        consumer_group.public_send(:parallel_segments=, count: 5)
        allow(consumer_group).to receive(:name).and_return('test-group')
      end

      it 'returns consumer group name with segment index appended using merge_key' do
        expect(consumer_group.segment_id).to eq(0)
      end

      it 'uses custom merge_key when specified' do
        consumer_group.public_send(:parallel_segments=, count: 5, merge_key: '--seg--')
        expect(consumer_group.segment_id).to eq(0)
      end
    end
  end

  describe '#segment_origin' do
    context 'when group name does not contain merge_key' do
      before do
        allow(consumer_group).to receive(:name).and_return('original-group')
        consumer_group.public_send(:parallel_segments=, count: 3)
      end

      it 'returns the original group name' do
        expect(consumer_group.segment_origin).to eq('original-group')
      end
    end

    context 'when group name contains default merge_key' do
      before do
        allow(consumer_group).to receive(:name).and_return('original-group-parallel-2')
        consumer_group.public_send(:parallel_segments=, count: 3)
      end

      it 'returns the group name without segment part' do
        expect(consumer_group.segment_origin).to eq('original-group')
      end
    end

    context 'when group name contains custom merge_key' do
      before do
        allow(consumer_group).to receive(:name).and_return('original-group--custom--2')
        consumer_group.public_send(:parallel_segments=, count: 3, merge_key: '--custom--')
      end

      it 'returns the group name without segment part' do
        expect(consumer_group.segment_origin).to eq('original-group')
      end
    end

    context 'when merge_key appears multiple times in the name' do
      before do
        allow(consumer_group).to receive(:name).and_return('original-parallel-group-parallel-2')
        consumer_group.public_send(:parallel_segments=, count: 3)
      end

      it 'returns the group name without the last segment part' do
        expect(consumer_group.segment_origin).to eq('original')
      end
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
