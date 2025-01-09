# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  before do
    allow(executor).to receive(:periodic)
    job.call
  end

  specify { expect(described_class.action).to eq(:tick) }

  it { expect(job.id).to eq(executor.id) }
  it { expect(job.group_id).to eq(executor.group_id) }
  it { expect(job.non_blocking?).to be(false) }

  it 'expect to run periodic on the executor' do
    expect(executor).to have_received(:periodic)
  end

  describe '#before_schedule' do
    before do
      allow(executor).to receive(:before_schedule_periodic)
      job.before_schedule
    end

    it 'expect to run before_schedule_periodic on the executor' do
      expect(executor).to have_received(:before_schedule_periodic)
    end
  end
end
