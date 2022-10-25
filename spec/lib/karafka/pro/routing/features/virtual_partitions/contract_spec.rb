# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      virtual_partitions: {
        active: true,
        partitioner: ->(_) { 1 },
        max_partitions: 2
      },
      manual_offset_management: {
        active: mom_active
      },
      active_job: {
        active: aj_active
      }
    }
  end

  let(:mom_active) { false }
  let(:aj_active) { false }
  let(:tags) { [] }

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when virtual partitions max_partitions is too low' do
    before { config[:virtual_partitions][:max_partitions] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when virtual partitions are active but no partitioner' do
    before { config[:virtual_partitions][:partitioner] = nil }

    it { expect(check).not_to be_success }
  end

  context 'when manual offset management is on with virtual partitions' do
    let(:mom_active) { true }

    it { expect(check).not_to be_success }
  end

  context 'when manual offset management is on with virtual partitions for active job' do
    let(:mom_active) { true }
    let(:aj_active) { true }

    it { expect(check).to be_success }
  end
end
