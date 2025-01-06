# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#expiring' do
    context 'when we use expiring without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.expiring.active?).to be(false)
      end
    end

    context 'when we use expiring with a ttl' do
      it 'expect to use proper active status' do
        topic.expiring(1)
        expect(topic.expiring.active?).to be(true)
      end
    end

    context 'when we use expiring multiple times with different values' do
      before do
        topic.expiring(1)
        topic.expire_in(2)
      end

      it 'expect to use proper active status' do
        expect(topic.expiring.active?).to be(true)
      end

      it 'expect not to add second expire' do
        expect(topic.filter.factories.count).to eq(1)
      end
    end
  end

  describe '#expiring?' do
    context 'when active' do
      before { topic.expiring(1) }

      it { expect(topic.expiring?).to be(true) }
    end

    context 'when not active' do
      before { topic.expiring }

      it { expect(topic.expiring?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:expiring]).to eq(topic.expiring.to_h) }
  end
end
