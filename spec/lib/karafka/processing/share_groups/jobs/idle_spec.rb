# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor) }

  let(:group_id) { SecureRandom.hex(6) }
  let(:client) { instance_double(Karafka::Connection::ShareGroups::Client) }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(build(:routing_topic)) }
  let(:executor) { Karafka::Processing::ShareGroups::Executor.new(group_id, client, coordinator) }

  it { expect(job.non_blocking?).to be(false) }

  specify { expect(described_class.action).to eq(:idle) }

  describe "#before_schedule" do
    before do
      allow(executor).to receive(:before_schedule_idle)
      job.before_schedule
    end

    it "expect to run before_schedule_idle on the executor" do
      expect(executor).to have_received(:before_schedule_idle).with(no_args)
    end
  end

  describe "#call" do
    before do
      allow(executor).to receive(:idle)
      job.call
    end

    it "expect to run idle on the executor" do
      expect(executor).to have_received(:idle).with(no_args)
    end
  end
end
