# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  before do
    allow(executor).to receive(:shutdown)
    job.call
  end

  specify { expect(described_class.action).to eq(:shutdown) }

  it { expect(job.id).to eq(executor.id) }
  it { expect(job.group_id).to eq(executor.group_id) }
  it { expect(job.non_blocking?).to eq(false) }

  it 'expect to run shutdown on the executor' do
    expect(executor).to have_received(:shutdown).with(no_args)
  end

  describe '#before_schedule' do
    before do
      allow(executor).to receive(:before_schedule_shutdown)
      job.before_schedule
    end

    it 'expect to run before_schedule_shutdown on the executor' do
      expect(executor).to have_received(:before_schedule_shutdown)
    end
  end
end
