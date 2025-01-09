# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      delaying: {
        active: true,
        delay: 5
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not boolean' do
    before { config[:delaying][:active] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when delay is zero' do
    before { config[:delaying][:delay] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when delay is not an integer' do
    before { config[:delaying][:delay] = 'test' }

    it { expect(check).not_to be_success }
  end
end
