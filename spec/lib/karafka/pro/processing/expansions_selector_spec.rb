# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:expansions) { described_class.new.find(topic) }

  let(:topic) { build(:routing_topic) }

  context 'when inline insights are enabled' do
    before { topic.inline_insights(true) }

    it { expect(expansions).to include(Karafka::Processing::InlineInsights::Consumer) }
  end

  context 'when offset metadata is enabled' do
    before { topic.offset_metadata }

    it { expect(expansions).to include(Karafka::Pro::Processing::OffsetMetadata::Consumer) }
  end
end
