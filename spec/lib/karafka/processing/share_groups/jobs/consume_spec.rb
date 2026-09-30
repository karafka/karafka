# frozen_string_literal: true

RSpec.describe_current do
  subject(:job) { described_class.new(executor, messages) }

  let(:group_id) { SecureRandom.hex(6) }
  let(:client) { instance_double(Karafka::Connection::ShareGroups::Client) }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(build(:routing_topic)) }
  let(:executor) { Karafka::Processing::ShareGroups::Executor.new(group_id, client, coordinator) }
  let(:messages) { [rand] }

  it { expect(job.non_blocking?).to be(false) }

  specify { expect(described_class.action).to eq(:consume) }

  it { expect(job.messages).to eq(messages) }

  describe "#before_schedule" do
    before do
      allow(executor).to receive(:before_schedule_consume)
      job.before_schedule
    end

    it "expect to run before_schedule_consume on the executor with messages" do
      expect(executor).to have_received(:before_schedule_consume).with(messages)
    end
  end

  describe "#before_call" do
    before do
      allow(executor).to receive(:before_consume)
      job.before_call
    end

    it "expect to run before_consume on the executor" do
      expect(executor).to have_received(:before_consume).with(no_args)
    end
  end

  describe "#call" do
    before do
      allow(executor).to receive(:consume)
      job.call
    end

    it "expect to run consume" do
      expect(executor).to have_received(:consume)
    end
  end

  describe "#after_call" do
    before do
      allow(executor).to receive(:after_consume)
      job.after_call
    end

    it "expect to run after_consume on the executor" do
      expect(executor).to have_received(:after_consume).with(no_args)
    end
  end
end
