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
      commit_async: true,
      events_poll: 0,
      "acknowledgement_commit_callback=": nil
    )
  end
  let(:rdkafka_config) { instance_double(Rdkafka::Config, share_consumer: share_consumer) }

  before do
    allow(Rdkafka::Config).to receive(:new).and_return(rdkafka_config)
    allow(Rdkafka::Config).to receive(:logger=)
  end

  after { client.close }

  describe "#batch_poll" do
    let(:message) do
      instance_double(Rdkafka::ShareConsumer::Message, topic: "t", partition: 0, offset: 1)
    end

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

    context "when the poll breaker requests a stop" do
      subject(:client) { described_class.new(subscription_group, -> { false }) }

      before { allow(share_consumer).to receive_messages(poll: [], events_poll: 0) }

      it "does not wait for the whole max wait time" do
        started_at = Time.now
        client.batch_poll(60_000)

        expect(Time.now - started_at).to be < 30
        expect(share_consumer).to have_received(:events_poll)
      end
    end

    it "polls in slices not longer than the tick interval" do
      allow(share_consumer).to receive_messages(poll: [], events_poll: 0)

      client.batch_poll(10)

      expect(share_consumer)
        .to have_received(:poll).with(satisfy { |timeout| timeout <= 10 }).at_least(:once)
    end

    it "reports acknowledgement commit outcomes through a callback" do
      allow(share_consumer).to receive(:poll).and_return([])

      client.batch_poll(100)

      expect(share_consumer).to have_received(:acknowledgement_commit_callback=)
        .with(kind_of(Karafka::Instrumentation::Callbacks::ShareGroups::AcknowledgementCommit))
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
      client.mark_as_accepted(message)

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

  describe "#events_poll" do
    before do
      allow(share_consumer).to receive_messages(poll: [], events_poll: 0)
      client.batch_poll(100)
    end

    it "services the main queue with the given timeout" do
      client.events_poll(100)

      expect(share_consumer).to have_received(:events_poll).with(100)
    end

    it "publishes a client.events_poll instrumentation event" do
      events = []
      Karafka.monitor.subscribe("client.events_poll") { |event| events << event }

      client.events_poll

      expect(events.first[:subscription_group]).to eq(subscription_group)
    end

    it "raises errors by default" do
      allow(share_consumer).to receive(:events_poll).and_raise(Rdkafka::RdkafkaError.new(-1))

      expect { client.events_poll }.to raise_error(Rdkafka::RdkafkaError)
    end

    it "swallows errors when safe" do
      allow(share_consumer).to receive(:events_poll).and_raise(Rdkafka::RdkafkaError.new(-1))

      expect { client.events_poll(safe: true) }.not_to raise_error
    end

    it "does not touch the consumer once closed" do
      calls = 0
      allow(share_consumer).to receive(:events_poll) { calls += 1 }

      client.close
      client.events_poll

      expect(calls).to eq(0)
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

    it "publishes a client.reset instrumentation event" do
      events = []
      Karafka.monitor.subscribe("client.reset") { |event| events << event }

      client.batch_poll(100)
      client.reset

      expect(events.size).to eq(1)
      expect(events.first[:subscription_group]).to eq(subscription_group)
    end
  end
end
