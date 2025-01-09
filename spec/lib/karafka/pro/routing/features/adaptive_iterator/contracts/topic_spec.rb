# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      adaptive_iterator: {
        active: true,
        safety_margin: 15,
        clean_after_yielding: true,
        marking_method: :mark_as_consumed
      },
      virtual_partitions: {
        active: false
      },
      long_running_job: {
        active: false
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when safety_margin is not an integer' do
    before { config[:adaptive_iterator][:safety_margin] = 'invalid_margin' }

    it { expect(check).not_to be_success }
  end

  context 'when safety_margin is not positive' do
    before { config[:adaptive_iterator][:safety_margin] = -5 }

    it { expect(check).not_to be_success }
  end

  context 'when safety_margin is 100 or more' do
    before { config[:adaptive_iterator][:safety_margin] = 100 }

    it { expect(check).not_to be_success }
  end

  context 'when marking_method is not a valid symbol' do
    before { config[:adaptive_iterator][:marking_method] = :invalid_method }

    it { expect(check).not_to be_success }
  end

  context 'when clean_after_yielding is not a boolean' do
    before { config[:adaptive_iterator][:clean_after_yielding] = nil }

    it { expect(check).not_to be_success }
  end

  context 'when trying to use the adaptive iterator with virtual partitions' do
    before { config[:virtual_partitions][:active] = true }

    it { expect(check).not_to be_success }
  end

  context 'when trying to use the adaptive iterator with long running job' do
    before { config[:long_running_job][:active] = true }

    it { expect(check).not_to be_success }
  end
end
