# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(topic, 2) }

  let(:topic) { build(:routing_share_topic) }
  let(:message) { build(:messages_message) }
  let(:consumer) { Karafka::Consumers::ShareGroup.new }

  describe "#topic and #partition" do
    it { expect(coordinator.topic).to eq(topic) }
    it { expect(coordinator.partition).to eq(2) }
  end

  describe "#revoked?" do
    it { expect(coordinator.revoked?).to be(false) }
  end

  describe "consume job lifecycle" do
    before { coordinator.start([message]) }

    it "is successful once the incremented consume job finishes and is marked success" do
      coordinator.increment(:consume)
      coordinator.success!(consumer)
      coordinator.decrement(:consume)

      expect(coordinator.success?).to be(true)
      expect(coordinator.failure?).to be(false)
    end

    it "is not successful while a consume job is still running" do
      coordinator.increment(:consume)

      expect(coordinator.success?).to be(false)
    end

    it "reports failure once a consumption fails" do
      coordinator.increment(:consume)
      coordinator.failure!(consumer, StandardError.new("boom"))
      coordinator.decrement(:consume)

      expect(coordinator.success?).to be(false)
      expect(coordinator.failure?).to be(true)
    end

    it "resets failure and consumption state on a fresh start" do
      coordinator.increment(:consume)
      coordinator.failure!(consumer, StandardError.new("boom"))
      coordinator.decrement(:consume)

      coordinator.start([message])

      expect(coordinator.failure?).to be(false)
      expect(coordinator.success?).to be(true)
    end
  end

  describe "#decrement below zero" do
    it "raises an invalid coordinator state error" do
      expect { coordinator.decrement(:consume) }
        .to raise_error(Karafka::Errors::InvalidCoordinatorStateError)
    end
  end
end
