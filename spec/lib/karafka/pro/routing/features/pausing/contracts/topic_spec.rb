# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      pause_timeout: 100,
      pause_max_timeout: 200,
      pause_with_exponential_backoff: false
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when pause_timeout is not int' do
    before { config[:pause_timeout] = 1.2 }

    it { expect(check).not_to be_success }
  end

  context 'when pause_timeout is less than 0' do
    before { config[:pause_timeout] = -1 }

    it { expect(check).not_to be_success }
  end

  context 'when pause_max_timeout is not int' do
    before { config[:pause_max_timeout] = 1.2 }

    it { expect(check).not_to be_success }
  end

  context 'when pause_max_timeout is less than 0' do
    before { config[:pause_max_timeout] = -1 }

    it { expect(check).not_to be_success }
  end

  context 'when pause_with_exponential_backoff is not boolean' do
    before { config[:pause_with_exponential_backoff] = -1 }

    it { expect(check).not_to be_success }
  end

  context 'when max is less than pause' do
    before do
      config[:pause_timeout] = 10
      config[:pause_max_timeout] = 1
    end

    it { expect(check).not_to be_success }
  end
end
