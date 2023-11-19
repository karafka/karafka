# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#delaying' do
    context 'when we use delaying without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.delaying.active?).to eq(false)
      end
    end

    context 'when we use delaying with a delay' do
      it 'expect to use proper active status' do
        topic.delaying(1)
        expect(topic.delaying.active?).to eq(true)
      end
    end

    context 'when we use delaying multiple times with different values' do
      before do
        topic.delaying(1)
        topic.delay_by(2)
      end

      it 'expect to use proper active status' do
        expect(topic.delaying.active?).to eq(true)
      end

      it 'expect not to add second expire' do
        expect(topic.filter.factories.count).to eq(1)
      end
    end
  end

  describe '#delaying?' do
    context 'when active' do
      before { topic.delaying(1) }

      it { expect(topic.delaying?).to eq(true) }
    end

    context 'when not active' do
      before { topic.delaying }

      it { expect(topic.delaying?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:delaying]).to eq(topic.delaying.to_h) }
  end
end
