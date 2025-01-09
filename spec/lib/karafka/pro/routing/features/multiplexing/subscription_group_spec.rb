# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:sg) { build(:routing_subscription_group) }

  let(:max) { 2 }
  let(:min) { 1 }

  describe '#multiplexing and multiplexing?' do
    before do
      sg.topics.first.subscription_group_details.merge!(
        multiplexing_max: max,
        multiplexing_min: min
      )
    end

    it { expect(sg.multiplexing?).to be(true) }
    it { expect(sg.multiplexing.active?).to be(true) }
    it { expect(sg.multiplexing.dynamic?).to be(true) }

    context 'when max is 1' do
      let(:max) { 1 }

      it { expect(sg.multiplexing?).to be(false) }
      it { expect(sg.multiplexing.active?).to be(false) }
      it { expect(sg.multiplexing.dynamic?).to be(false) }
    end

    context 'when min and max are the same' do
      let(:min) { 3 }
      let(:max) { 3 }

      it { expect(sg.multiplexing?).to be(true) }
      it { expect(sg.multiplexing.active?).to be(true) }
      it { expect(sg.multiplexing.dynamic?).to be(false) }
    end
  end
end
