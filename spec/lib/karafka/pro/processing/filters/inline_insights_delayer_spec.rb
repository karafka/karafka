# frozen_string_literal: true

RSpec.describe_current do
  subject(:delayer) { described_class.new(topic, partition) }

  let(:topic) { build(:routing_topic) }
  let(:partition) { rand(100) }
  let(:message) { build(:messages_message, topic: topic.name, partition: partition) }

  context 'when there are no messages' do
    before { delayer.apply!([]) }

    it { expect(delayer.applied?).to eq(false) }
    it { expect(delayer.timeout).to eq(0) }
    it { expect(delayer.action).to eq(:skip) }
  end

  context 'when insights exist' do
    before do
      expect(Karafka::Processing::InlineInsights::Tracker)
        .to receive(:find)
        .with(topic, partition)
        .and_return(rand => rand)

      delayer.apply!([message])
    end

    it { expect(delayer.applied?).to eq(false) }
    it { expect(delayer.timeout).to eq(0) }
    it { expect(delayer.action).to eq(:skip) }
  end

  context 'when insights do not exist' do
    before { delayer.apply!([message]) }

    it { expect(delayer.applied?).to eq(true) }
    it { expect(delayer.timeout).to eq(5_000) }
    it { expect(delayer.action).to eq(:pause) }
  end
end
