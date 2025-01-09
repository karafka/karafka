# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:task) do
    {
      id: 'task_1',
      cron: '* * * * *',
      enabled: true,
      changed: false,
      previous_time: 1_679_334_800
    }
  end

  context 'when task is valid' do
    it { expect(contract.call(task)).to be_success }
  end

  context 'when id does not match the required format' do
    before { task[:id] = 'invalid id!' }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when id is not a string' do
    before { task[:id] = 12_345 }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when cron is an empty string' do
    before { task[:cron] = '' }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when cron is not a string' do
    before { task[:cron] = 12_345 }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when enabled is nil' do
    before { task[:enabled] = nil }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when enabled is not a boolean' do
    before { task[:enabled] = 'true' }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when changed is nil' do
    before { task[:changed] = nil }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when changed is not a boolean' do
    before { task[:changed] = 'false' }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when previous_time is not numeric' do
    before { task[:previous_time] = 'not numeric' }

    it { expect(contract.call(task)).not_to be_success }
  end
end
