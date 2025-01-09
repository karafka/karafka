# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      filtering: {
        active: true,
        factories: []
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not boolean' do
    before { config[:filtering][:active] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when factories are not in array' do
    before { config[:filtering][:factories] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when factories do not respond to #call' do
    before { config[:filtering][:factories] = [rand] }

    it { expect(check).not_to be_success }
  end
end
