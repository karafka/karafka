# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#patterns' do
    context 'when we use patterns without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.patterns.active?).to eq(false)
      end
    end

    context 'when we use patterns with a active and a type' do
      it 'expect to use proper active status' do
        topic.patterns(true, 1)
        expect(topic.patterns.active?).to eq(true)
      end
    end

    context 'when we use patterns multiple times with different values' do
      before do
        topic.patterns(true)
        topic.expire_in(false)
      end

      it 'expect to use proper active status' do
        expect(topic.patterns.active?).to eq(true)
      end
    end
  end

  describe '#patterns?' do
    context 'when active' do
      before { topic.patterns(true) }

      it { expect(topic.patterns?).to eq(true) }
    end

    context 'when not active' do
      before { topic.patterns }

      it { expect(topic.patterns?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:patterns]).to eq(topic.patterns.to_h) }
  end
end
