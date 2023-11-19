# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#filter' do
    context 'when we use filter without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.filter.active?).to eq(false)
      end
    end

    context 'when we use filter with a factory status' do
      it 'expect to use proper active status' do
        topic.filter('filter1')
        expect(topic.filter.active?).to eq(true)
      end
    end

    context 'when we use filter multiple times with different values' do
      before do
        topic.filter('filter1')
        topic.filter('filter2')
      end

      it 'expect to use proper active status' do
        expect(topic.filter.active?).to eq(true)
      end

      it 'expect to accumulate all the filters' do
        expect(topic.filter.factories).to eq(%w[filter1 filter2])
      end
    end
  end

  describe '#filtering?' do
    context 'when active' do
      before { topic.filter(true) }

      it { expect(topic.filtering?).to eq(true) }
    end

    context 'when not active' do
      before { topic.filter }

      it { expect(topic.filtering?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:filtering]).to eq(topic.filter.to_h) }
  end
end
