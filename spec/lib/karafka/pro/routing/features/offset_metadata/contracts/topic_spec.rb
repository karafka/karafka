# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      offset_metadata: {
        active: true,
        deserializer: -> {},
        cache: true
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not boolean' do
    before { config[:offset_metadata][:active] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when cache flag is not boolean' do
    before { config[:offset_metadata][:cache] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when deserializer is not callable' do
    before { config[:offset_metadata][:deserializer] = rand }

    it { expect(check).not_to be_success }
  end
end
