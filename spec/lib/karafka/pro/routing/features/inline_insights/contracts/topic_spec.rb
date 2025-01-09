# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      inline_insights: {
        active: true,
        required: true
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not boolean' do
    before { config[:inline_insights][:active] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when required is not boolean' do
    before { config[:inline_insights][:required] = rand }

    it { expect(check).not_to be_success }
  end
end
