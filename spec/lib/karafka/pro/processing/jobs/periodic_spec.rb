# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  before do
    allow(executor).to receive(:periodic)
    job.call
  end

  it { expect(job.id).to eq(executor.id) }
  it { expect(job.group_id).to eq(executor.group_id) }
  it { expect(job.non_blocking?).to eq(false) }

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
