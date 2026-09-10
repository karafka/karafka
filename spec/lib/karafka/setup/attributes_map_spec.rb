# frozen_string_literal: true

RSpec.describe_current do
  subject(:map) { described_class }

  let(:settings) do
    {
      # Producer only
      "message.send.max.retries": 1_000,
      # Consumer only
      "max.poll.interval.ms": 2_000,
      # Both
      "ssl.crl.location": ""
    }
  end

  describe "#consumer_group" do
    subject(:stripped) { described_class.consumer_group(settings) }

    it "expect to keep consumer and shared settings" do
      expect(stripped.key?(:"message.send.max.retries")).to be(false)
      expect(stripped[:"max.poll.interval.ms"]).to eq(2_000)
      expect(stripped[:"ssl.crl.location"]).to eq("")
    end
  end

  describe "#consumer (legacy alias)" do
    subject(:stripped) { described_class.consumer(settings) }

    it "expect to behave exactly as #consumer_group" do
      expect(stripped).to eq(described_class.consumer_group(settings))
    end
  end

  describe "#share_group" do
    subject(:stripped) { described_class.share_group(share_settings) }

    let(:share_settings) do
      {
        # Share specific
        "share.acknowledgement.mode": "explicit",
        "max.poll.records": 250,
        # Rejected by librdkafka for share consumers
        "auto.offset.reset": "earliest",
        "enable.auto.offset.store": false,
        "group.instance.id": "s1",
        "partition.assignment.strategy": "range",
        # Shared
        "ssl.crl.location": "",
        # Producer only
        "message.send.max.retries": 1_000
      }
    end

    it "expect to keep share-specific and shared settings" do
      expect(stripped[:"share.acknowledgement.mode"]).to eq("explicit")
      expect(stripped[:"max.poll.records"]).to eq(250)
      expect(stripped[:"ssl.crl.location"]).to eq("")
    end

    it "expect to strip settings librdkafka rejects for share consumers" do
      expect(stripped.key?(:"auto.offset.reset")).to be(false)
      expect(stripped.key?(:"enable.auto.offset.store")).to be(false)
      expect(stripped.key?(:"group.instance.id")).to be(false)
      expect(stripped.key?(:"partition.assignment.strategy")).to be(false)
    end

    it "expect to strip producer-only settings" do
      expect(stripped.key?(:"message.send.max.retries")).to be(false)
    end
  end

  describe "#producer" do
    subject(:stripped) { described_class.producer(settings) }

    it "expect to keep producer and shared settings" do
      expect(stripped.key?(:"max.poll.interval.ms")).to be(false)
      expect(stripped[:"message.send.max.retries"]).to eq(1_000)
      expect(stripped[:"ssl.crl.location"]).to eq("")
    end
  end

  describe "#generate" do
    subject(:generated_list) { described_class.generate }

    it "expect to have correct settings for both consumer and producer" do
      expect(generated_list[:consumer]).to eq(described_class::CONSUMER)
      expect(generated_list[:producer]).to eq(described_class::PRODUCER)
    end
  end
end
