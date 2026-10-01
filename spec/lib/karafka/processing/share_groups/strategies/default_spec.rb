# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) do
    instance = Class.new(Karafka::ShareConsumer).new
    instance.singleton_class.include(described_class)
    instance.client = client
    instance.coordinator = coordinator
    instance.messages = messages
    instance
  end

  let(:client) do
    instance_double(
      Karafka::Connection::ShareGroups::Client,
      mark_as_accepted: true,
      mark_as_released: true,
      mark_as_rejected: true,
      commit: nil
    )
  end

  let(:topic) { build(:routing_share_topic) }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(topic, 0) }
  let(:first) { build(:messages_message) }
  let(:second) { build(:messages_message) }
  let(:messages) do
    Karafka::Messages::Builders::Messages.call([first, second], topic, 0, Time.now)
  end

  describe "#handle_after_consume" do
    context "when consumption succeeded" do
      before { coordinator.success!(consumer) }

      it "releases unacknowledged records by default (the topic default)" do
        consumer.handle_after_consume

        expect(client).to have_received(:mark_as_released).with(first)
        expect(client).to have_received(:mark_as_released).with(second)
      end

      it "flushes the acknowledgements asynchronously" do
        consumer.handle_after_consume

        expect(client).to have_received(:commit).with(no_args)
      end

      it "does not acknowledge again records the consumer already acknowledged" do
        consumer.mark_as_accepted(first)
        consumer.handle_after_consume

        expect(client).to have_received(:mark_as_accepted).with(first)
        expect(client).not_to have_received(:mark_as_released).with(first)
        expect(client).to have_received(:mark_as_released).with(second)
      end

      context "when the topic accepts unacknowledged records" do
        before { topic.acknowledgements(unacknowledged: :accept) }

        it "accepts them" do
          consumer.handle_after_consume

          expect(client).to have_received(:mark_as_accepted).with(first)
          expect(client).to have_received(:mark_as_accepted).with(second)
        end
      end
    end

    context "when consumption failed" do
      before do
        topic.acknowledgements(unacknowledged: :accept)
        coordinator.failure!(consumer, StandardError.new)
      end

      it "always releases unacknowledged records" do
        consumer.handle_after_consume

        expect(client).to have_received(:mark_as_released).with(first)
        expect(client).to have_received(:mark_as_released).with(second)
        expect(client).not_to have_received(:mark_as_accepted)
      end
    end
  end

  describe "#handle_before_consume" do
    it "starts tracking acknowledgements anew for the next batch" do
      consumer.mark_as_accepted(first)
      consumer.handle_before_consume

      expect(consumer.mark_as_accepted(first)).to be(true)
    end
  end
end
