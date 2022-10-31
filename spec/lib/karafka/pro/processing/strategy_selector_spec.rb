# frozen_string_literal: true

RSpec.describe_current do
  subject(:selected_strategy) { described_class.new.find(topic) }

  let(:topic) { build(:routing_topic) }

  context 'when no features enabled' do
    it { expect(selected_strategy).to eq(Karafka::Processing::Strategies::Default) }
  end

  context 'when manual offset management is on' do
    before { topic.manual_offset_management(true) }

    it { expect(selected_strategy).to eq(Karafka::Processing::Strategies::Mom) }
  end
end
