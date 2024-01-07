# frozen_string_literal: true

RSpec.describe_current do
  subject(:sg) { build(:routing_subscription_group) }

  let(:count) { 2 }
  let(:dynamic) { true }

  describe '#multiplexing and multiplexing?' do
    before do
      sg.topics.first.subscription_group_details.merge!(
        multiplexing_count: count,
        multiplexing_dynamic: dynamic
      )
    end

    it { expect(sg.multiplexing.active?).to eq(true) }
    it { expect(sg.multiplexing.dynamic?).to eq(true) }

    context 'when count is 1' do
      let(:count) { 1 }

      it { expect(sg.multiplexing.active?).to eq(false) }
      it { expect(sg.multiplexing.dynamic?).to eq(true) }
    end
  end
end
