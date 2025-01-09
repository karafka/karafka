# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      periodic_job: {
        active: true,
        interval: 2_500,
        during_pause: true,
        during_retry: true,
        materialized: true
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not boolean' do
    before { config[:periodic_job][:active] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when during_pause flag is not boolean' do
    before { config[:periodic_job][:during_pause] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when during_retry flag is not boolean' do
    before { config[:periodic_job][:during_retry] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when interval is not integer' do
    before { config[:periodic_job][:interval] = 1.4 }

    it { expect(check).not_to be_success }
  end

  context 'when interval is less than 100ms' do
    before { config[:periodic_job][:interval] = 99 }

    it { expect(check).not_to be_success }
  end
end
