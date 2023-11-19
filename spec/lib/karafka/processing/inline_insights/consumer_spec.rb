# frozen_string_literal: true

RSpec.describe_current do
  let(:consumer) { Class.new { include Karafka::Processing::InlineInsights::Consumer }.new }
  let(:topic) { build(:routing_topic) }
  let(:partition) { 5 }
  let(:tracker) { Karafka::Processing::InlineInsights::Tracker.instance }
  let(:insight_data) { { 'key' => 'value' } }

  before do
    allow(consumer).to receive(:topic).and_return(topic)
    allow(consumer).to receive(:partition).and_return(partition)
  end

  describe '#insights' do
    subject(:insights) { consumer.insights }

    context 'when insights exist' do
      before do
        allow(tracker).to receive(:find).with(topic, partition).and_return(insight_data)
      end

      it 'returns the insights data' do
        expect(insights).to eq(insight_data)
      end
    end

    context 'when insights do not exist' do
      before do
        allow(tracker).to receive(:find).with(topic, partition).and_return({})
      end

      it 'returns an empty hash' do
        expect(insights).to eq({})
      end
    end

    context 'when we have insights and they were updated' do
      let(:new_insight_data) { { rand => rand } }

      before do
        allow(tracker)
          .to receive(:find)
          .with(topic, partition)
          .and_return(insight_data, new_insight_data)
      end

      it 'expect to refresh them and return new' do
        expect(consumer.insights).to eq(insight_data)
        expect(consumer.insights).to eq(new_insight_data)
      end
    end

    context 'when we had no insights but came' do
      let(:insight_data) { {} }
      let(:new_insight_data) { { rand => rand } }

      before do
        allow(tracker)
          .to receive(:find)
          .with(topic, partition)
          .and_return(insight_data, new_insight_data)
      end

      it 'expect to refresh them and return new' do
        expect(consumer.insights).to eq(insight_data)
        expect(consumer.insights).to eq(new_insight_data)
      end
    end

    context 'when we have insights and they were lost' do
      let(:new_insight_data) { {} }

      before do
        allow(tracker)
          .to receive(:find)
          .with(topic, partition)
          .and_return(insight_data, new_insight_data)
      end

      it 'expect not to replace with empty' do
        expect(consumer.insights).to eq(insight_data)
        expect(consumer.insights).to eq(insight_data)
      end
    end
  end

  describe '#insights?' do
    subject { consumer.insights? }

    context 'when insights exist' do
      before do
        allow(tracker).to receive(:find).with(topic, partition).and_return(insight_data)
      end

      it { is_expected.to be_truthy }
    end

    context 'when insights do not exist' do
      it { is_expected.to be_falsey }
    end
  end

  describe '#statistics' do
    it 'is an alias for #insights' do
      expect(consumer.method(:statistics)).to eq consumer.method(:insights)
    end
  end

  describe '#statistics?' do
    it 'is an alias for #insights?' do
      expect(consumer.method(:statistics?)).to eq consumer.method(:insights?)
    end
  end
end
