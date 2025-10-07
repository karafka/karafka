# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      pausing: {
        active: true,
        timeout: 100,
        max_timeout: 200,
        with_exponential_backoff: false
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when pausing.active is not boolean' do
    before { config[:pausing][:active] = 'true' }

    it { expect(check).not_to be_success }
  end

  context 'when pausing.timeout is not int' do
    before { config[:pausing][:timeout] = 1.2 }

    it { expect(check).not_to be_success }
  end

  context 'when pausing.timeout is less than or equal to 0' do
    before { config[:pausing][:timeout] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when pausing.max_timeout is not int' do
    before { config[:pausing][:max_timeout] = 1.2 }

    it { expect(check).not_to be_success }
  end

  context 'when pausing.max_timeout is less than or equal to 0' do
    before { config[:pausing][:max_timeout] = -1 }

    it { expect(check).not_to be_success }
  end

  context 'when pausing.with_exponential_backoff is not boolean' do
    before { config[:pausing][:with_exponential_backoff] = -1 }

    it { expect(check).not_to be_success }
  end

  context 'when pausing.max_timeout is less than pausing.timeout' do
    before do
      config[:pausing][:timeout] = 10
      config[:pausing][:max_timeout] = 1
    end

    it { expect(check).not_to be_success }
  end
end
