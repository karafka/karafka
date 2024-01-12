# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      subscription_group_details: {
        multiplexing_min: min,
        multiplexing_max: max,
        multiplexing_boot: boot
      }
    }
  end

  let(:min) { 1 }
  let(:max) { 1 }
  let(:boot) { 1 }

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when min is below 1' do
    let(:min) { 0 }

    it { expect(check).not_to be_success }
  end

  context 'when max is below 1' do
    let(:max) { 0 }

    it { expect(check).not_to be_success }
  end

  context 'when min is more than max' do
    let(:max) { 1 }
    let(:min) { 2 }

    it { expect(check).not_to be_success }
  end

  context 'when boot is below 1' do
    let(:boot) { 0 }

    it { expect(check).not_to be_success }
  end

  context 'when boot is less than min' do
    let(:max) { 10 }
    let(:min) { 7 }
    let(:boot) { 2 }

    it { expect(check).not_to be_success }
  end

  context 'when boot is more than max' do
    let(:max) { 10 }
    let(:min) { 7 }
    let(:boot) { 22 }

    it { expect(check).not_to be_success }
  end

  context 'when not in dynamic mode, boot should not be different than min and max' do
    let(:max) { 5 }
    let(:min) { 5 }
    let(:boot) { 2 }

    it { expect(check).not_to be_success }
  end
end
