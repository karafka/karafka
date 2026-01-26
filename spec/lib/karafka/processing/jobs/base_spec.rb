# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new }

  specify { expect(described_class.action).to be_nil }

  describe "#non_blocking?" do
    it "expect all the newly created jobs to be blocking" do
      expect(job.non_blocking?).to be(false)
    end
  end

  describe "#call" do
    it { expect { job.call }.to raise_error(NotImplementedError) }
  end

  describe "#before_schedule" do
    it { expect { job.before_schedule }.to raise_error(NotImplementedError) }
  end

  describe "#finished? and #finish!" do
    it { expect(job.finished?).to be(false) }

    context "when job is finished" do
      before { job.finish! }

      it { expect(job.finished?).to be(true) }
    end
  end
end
