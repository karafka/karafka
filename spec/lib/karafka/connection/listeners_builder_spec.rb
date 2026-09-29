# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) { described_class.new }

  let(:subscription_group) { build(:routing_subscription_group) }
  let(:jobs_queue) { Karafka::Processing::ConsumerGroups::JobsQueue.new }
  let(:scheduler) { nil }

  after { listener.shutdown if defined?(listener) && listener.respond_to?(:shutdown) }

  describe "#call" do
    context "when the subscription group is a consumer group" do
      let(:listener) { builder.call(subscription_group, jobs_queue, scheduler) }

      it "builds a consumer-group listener" do
        expect(listener).to be_a(Karafka::Connection::ConsumerGroups::Listener)
      end
    end

    context "when the subscription group is a share group" do
      let(:share_group) { Karafka::Routing::ShareGroups::Group.new("webhooks") }
      let(:listener) { builder.call(subscription_group, jobs_queue, scheduler) }

      before { allow(subscription_group).to receive(:group).and_return(share_group) }

      it "builds a share-group listener" do
        expect(listener).to be_a(Karafka::Connection::ShareGroups::Listener)
      end
    end
  end
end
