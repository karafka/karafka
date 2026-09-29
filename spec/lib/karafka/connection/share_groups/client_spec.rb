# frozen_string_literal: true

RSpec.describe_current do
  subject(:client) { described_class.new(subscription_group) }

  let(:subscription_group) { build(:routing_subscription_group) }
  let(:share_consumer) do
    instance_double(
      Rdkafka::ShareConsumer,
      name: "share-client",
      subscribe: nil,
      close: nil,
      commit_sync: true,
      commit_async: true
    )
  end
  let(:rdkafka_config) { instance_double(Rdkafka::Config, share_consumer: share_consumer) }

  before do
    allow(Rdkafka::Config).to receive(:new).and_return(rdkafka_config)
    allow(Rdkafka::Config).to receive(:logger=)
  end

  after { client.close }

  describe "#batch_poll" do
    let(:message) { instance_double(Rdkafka::Consumer::Message) }

    it "returns the polled records" do
      allow(share_consumer).to receive(:poll).and_return([message])

      expect(client.batch_poll(100)).to eq([message])
    end

    it "returns an empty array when nothing was polled" do
      allow(share_consumer).to receive(:poll).and_return([])

      expect(client.batch_poll(100)).to eq([])
    end

    it "skips record-level error entries and keeps the valid messages" do
      error = Rdkafka::RdkafkaError.new(-1)
      allow(share_consumer).to receive(:poll).and_return([message, error])

      expect(client.batch_poll(100)).to eq([message])
    end

    it "subscribes to the subscription group topics when building the consumer" do
      allow(share_consumer).to receive(:poll).and_return([])

      client.batch_poll(100)

      expect(share_consumer).to have_received(:subscribe).with(*subscription_group.subscriptions)
    end
  end

  describe "acknowledgements" do
    let(:message) { build(:messages_message) }

    before do
      allow(share_consumer).to receive_messages(poll: [], acknowledge: nil)
      client.batch_poll(100)
    end

    it "acknowledges a consumed message as accepted" do
      client.mark_as_consumed(message)

      expect(share_consumer).to have_received(:acknowledge).with(message, :accept)
    end

    it "acknowledges a released message" do
      client.mark_as_released(message)

      expect(share_consumer).to have_received(:acknowledge).with(message, :release)
    end

    it "acknowledges a rejected message" do
      client.mark_as_rejected(message)

      expect(share_consumer).to have_received(:acknowledge).with(message, :reject)
    end
  end

  describe "#commit and #commit!" do
    before { allow(share_consumer).to receive(:poll).and_return([]) }

    it "commits asynchronously by default" do
      client.batch_poll(100)
      client.commit

      expect(share_consumer).to have_received(:commit_async)
    end

    it "commits synchronously via commit!" do
      client.batch_poll(100)
      client.commit!

      expect(share_consumer).to have_received(:commit_sync)
    end
  end

  describe "#close and #closed?" do
    before { allow(share_consumer).to receive(:poll).and_return([]) }

    it "closes the underlying consumer and marks the client closed" do
      client.batch_poll(100)
      client.close

      expect(client).to be_closed
      expect(share_consumer).to have_received(:close)
    end
  end

  describe "#reset" do
    before { allow(share_consumer).to receive(:poll).and_return([]) }

    it "allows the client to be used again after being closed" do
      client.batch_poll(100)
      client.reset

      expect(client).not_to be_closed
    end
  end
end
