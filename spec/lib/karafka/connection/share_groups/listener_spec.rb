# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new(subscription_group, jobs_queue, scheduler) }

  let(:subscription_group) { build(:routing_subscription_group) }
  let(:jobs_queue) { nil }
  let(:scheduler) { nil }

  # The full poll-process-acknowledge loop runs against a broker and is covered by the share-group
  # integration specs. Here we only assert the lifecycle/status surface that the connection
  # manager drives, without starting the async thread.

  describe "status API" do
    it { expect(listener).to respond_to(:start!) }
    it { expect(listener).to respond_to(:quiet!) }
    it { expect(listener).to respond_to(:stop!) }

    it "starts pending and not active" do
      expect(listener).to be_pending
      expect(listener).not_to be_active
    end
  end

  describe "#shutdown when pending" do
    it "moves straight to stopped without touching the client" do
      listener.shutdown

      expect(listener).to be_stopped
    end
  end

  describe "#id" do
    it { expect(listener.id).to be_a(String) }
  end
end
