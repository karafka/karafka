# frozen_string_literal: true

RSpec.describe_current do
  subject(:batch) { described_class.new(jobs_queue) }

  let(:jobs_queue) { Karafka::Processing::ConsumerGroups::JobsQueue.new }
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
      expect(batch).to all be_a(Karafka::Connection::ConsumerGroups::Listener)
    end
  end

  describe "share group dispatch" do
    let(:share_group) { Karafka::Routing::ShareGroups::Group.new("webhooks") }

    before do
      allow(subscription_group).to receive(:group).and_return(share_group)
      allow(Karafka::App).to receive(:subscription_groups).and_return(
        share_group => [subscription_group]
      )
    end

    it "expect to assemble share-group listeners for share groups" do
      expect(described_class.new(jobs_queue))
        .to all be_a(Karafka::Connection::ShareGroups::Listener)
    end
  end

  after do
    allow(Karafka::App).to receive(:subscription_groups).and_call_original
  end
end
