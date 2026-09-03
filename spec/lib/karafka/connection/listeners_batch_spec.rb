# frozen_string_literal: true

RSpec.describe_current do
  subject(:batch) { described_class.new(jobs_queue) }

  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:consumer_group) { build(:routing_consumer_group) }
  let(:subscription_group) { build(:routing_subscription_group) }

  after { batch.each(&:shutdown) }

  describe "#each" do
    before do
      allow(Karafka::App).to receive(:subscription_groups).and_return(
        consumer_group => [subscription_group]
      )
    end

    it "expect to yield each listener" do
      expect(batch).to all be_a(Karafka::Connection::Listener)
    end
  end

  describe "share group guard" do
    let(:share_group) { Karafka::Routing::Groups::ShareGroup.new("webhooks") }

    before do
      allow(Karafka::App).to receive(:subscription_groups).and_return(
        share_group => [subscription_group]
      )
    end

    it "expect to refuse assembling listeners for share groups" do
      expect { described_class.new(jobs_queue) }
        .to raise_error(Karafka::Errors::ShareGroupsNotImplementedError, /webhooks/)
    end
  end

  # The share-group guard raises before any listener is built, so there is nothing to shut down.
  # We reset the stub before the top-level `after` hook so it does not re-trigger the guard.
  after do
    allow(Karafka::App).to receive(:subscription_groups).and_call_original
  end
end
