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

  let(:client) { instance_double(Karafka::Connection::ShareGroups::Client, settle: nil) }
  let(:topic) { build(:routing_share_topic) }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(topic, 0) }
  let(:messages) do
    Karafka::Messages::Builders::Messages.call([build(:messages_message)], topic, 0, Time.now)
  end

  describe "#handle_after_consume" do
    context "when consumption succeeded" do
      before { coordinator.success!(consumer) }

      it "settles unacknowledged records with the topic default (release)" do
        consumer.handle_after_consume

        expect(client).to have_received(:settle).with(messages.raw, :release)
      end

      context "when the topic accepts unacknowledged records" do
        before { topic.acknowledgements(unacknowledged: :accept) }

        it "accepts them" do
          consumer.handle_after_consume

          expect(client).to have_received(:settle).with(messages.raw, :accept)
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

        expect(client).to have_received(:settle).with(messages.raw, :release)
      end
    end
  end
end
