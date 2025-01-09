# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#inline_insights' do
    context 'when we use inline_insights without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.inline_insights.active?).to be(false)
      end
    end

    context 'when we use inline_insights with a true' do
      it 'expect to use proper active status' do
        topic.inline_insights(true)
        expect(topic.inline_insights.active?).to be(true)
      end
    end

    context 'when we use inline_insights via setting only required' do
      it 'expect to use proper active status' do
        topic.inline_insights(required: true)
        expect(topic.inline_insights.active?).to be(true)
        expect(topic.inline_insights.required?).to be(true)
      end
    end

    context 'when we use inline_insights multiple times with different values' do
      before do
        topic.inline_insights(true)
        topic.inline_insights(false)
      end

      it 'expect to use proper active status' do
        expect(topic.inline_insights.active?).to be(true)
      end

      it 'expect not to add any filters' do
        expect(topic.filter.factories.count).to eq(0)
      end
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:inline_insights]).to eq(topic.inline_insights.to_h) }
  end
end
