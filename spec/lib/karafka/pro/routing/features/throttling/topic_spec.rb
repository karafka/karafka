# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#throttling' do
    context 'when we use throttling without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.throttling.active?).to be(false)
      end
    end

    context 'when we use throttling with good limit value' do
      it 'expect to use proper active status' do
        topic.throttling(limit: 100)
        expect(topic.throttling.active?).to be(true)
      end
    end

    context 'when we use throttling multiple times with different values' do
      it 'expect to use proper active status' do
        topic.throttling(limit: 100)
        topic.throttle(limit: Float::INFINITY)
        expect(topic.throttling.active?).to be(true)
      end
    end
  end

  describe '#throttling?' do
    context 'when active' do
      before { topic.throttling(limit: 100) }

      it { expect(topic.throttling?).to be(true) }
    end

    context 'when not active' do
      before { topic.throttling }

      it { expect(topic.throttling?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:throttling]).to eq(topic.throttling.to_h) }
  end
end
