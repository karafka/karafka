# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  before do
    allow(executor).to receive(:idle)
    job.call
  end

  specify { expect(described_class.action).to eq(:idle) }

  it { expect(job.id).to eq(executor.id) }
  it { expect(job.group_id).to eq(executor.group_id) }
  it { expect(job.non_blocking?).to be(false) }

  it "expect to run idle on the executor" do
    expect(executor).to have_received(:idle)
  end

  describe "#before_schedule" do
    before do
      allow(executor).to receive(:before_schedule_idle)
      job.before_schedule
    end

    it "expect to run before_schedule_idle on the executor" do
      expect(executor).to have_received(:before_schedule_idle)
    end
  end
end
