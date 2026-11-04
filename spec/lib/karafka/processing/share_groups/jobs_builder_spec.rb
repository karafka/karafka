# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) { described_class.new }

  let(:group_id) { SecureRandom.hex(6) }
  let(:client) { instance_double(Karafka::Connection::ShareGroups::Client) }
  let(:topic) { build(:routing_share_topic) }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(topic, 0) }
  let(:executor) { Karafka::Processing::ShareGroups::Executor.new(group_id, client, coordinator) }

  describe "#consume" do
    it do
      job = builder.consume(executor, [])
      expect(job).to be_a(Karafka::Processing::ShareGroups::Jobs::Consume)
    end
  end

  describe "#idle" do
    it do
      job = builder.idle(executor)
      expect(job).to be_a(Karafka::Processing::ShareGroups::Jobs::Idle)
    end
  end

  describe "#shutdown" do
    it do
      job = builder.shutdown(executor)
      expect(job).to be_a(Karafka::Processing::ShareGroups::Jobs::Shutdown)
    end
  end
end
