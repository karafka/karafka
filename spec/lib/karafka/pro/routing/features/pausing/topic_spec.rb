# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#pause' do
    context 'when setting only timeout with rest of defaults' do
      before { topic.pause(timeout: 100) }

      it 'expect to change only timeout' do
        expect(topic.pause_timeout).to eq(100)
        expect(topic.pause_max_timeout).to eq(1)
        expect(topic.pause_with_exponential_backoff).to be(false)
      end
    end

    context 'when setting only max_timeout with rest of defaults' do
      before { topic.pause(max_timeout: 100) }

      it 'expect to change only max_timeout' do
        expect(topic.pause_timeout).to eq(1)
        expect(topic.pause_max_timeout).to eq(100)
        expect(topic.pause_with_exponential_backoff).to be(false)
      end
    end

    context 'when setting only with_exponential_backoff with rest of defaults' do
      before { topic.pause(with_exponential_backoff: true) }

      it 'expect to change only with_exponential_backoff' do
        expect(topic.pause_timeout).to eq(1)
        expect(topic.pause_max_timeout).to eq(1)
        expect(topic.pause_with_exponential_backoff).to be(true)
      end
    end

    context 'when we change all' do
      before do
        topic.pause(
          timeout: 100,
          max_timeout: 50,
          with_exponential_backoff: true
        )
      end

      it 'expect to change all' do
        expect(topic.pause_timeout).to eq(100)
        expect(topic.pause_max_timeout).to eq(50)
        expect(topic.pause_with_exponential_backoff).to be(true)
      end
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h.key?(:pause_timeout)).to be(true) }
    it { expect(topic.to_h.key?(:pause_max_timeout)).to be(true) }
    it { expect(topic.to_h.key?(:pause_with_exponential_backoff)).to be(true) }
  end
end
