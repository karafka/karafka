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
        # Consumer-group specific - filtered out of the shared settings set for share consumers
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

    it "expect to filter out consumer-group specific settings" do
      expect(stripped.key?(:"auto.offset.reset")).to be(false)
      expect(stripped.key?(:"enable.auto.offset.store")).to be(false)
      expect(stripped.key?(:"group.instance.id")).to be(false)
      expect(stripped.key?(:"partition.assignment.strategy")).to be(false)
    end

    it "expect to filter out producer-only settings" do
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
      expect(generated_list[:consumer]).to eq(described_class::CONSUMER_GROUP)
      expect(generated_list[:producer]).to eq(described_class::PRODUCER)
    end
  end

  # Drift protection for the share scope. The #generate spec above guards CONSUMER_GROUP against
  # new librdkafka options; these invariants extend that guard to SHARE_GROUP: when
  # CONSUMER_GROUP gains a new attribute, this spec fails until the attribute is consciously
  # added either to SHARE_GROUP or to the excluded list below.
  describe "share group scope drift protection" do
    # Attributes deliberately not part of the share scope: consumer-group only concepts (offset
    # commits and resets, client-side assignment, static group membership) plus properties the
    # librdkafka 2.15.0 CONFIGURATION.md marks as not supported for share consumers
    let(:consumer_group_only) do
      %i[
        auto.commit.enable
        auto.commit.interval.ms
        auto.offset.reset
        consume_cb
        enable.auto.commit
        enable.auto.offset.store
        enable.partition.eof
        fetch.error.backoff.ms
        fetch.queue.backoff.ms
        group.instance.id
        group.remote.assignor
        isolation.level
        message.copy.max.bytes
        offset_commit_cb
        partition.assignment.strategy
        queued.max.messages.kbytes
        queued.min.messages
        rebalance_cb
        topic.blacklist
      ]
    end

    let(:share_group_only) do
      %i[
        max.poll.records
        share.acknowledgement.mode
      ]
    end

    it "expect every consumer-group attribute to be shared or explicitly excluded" do
      expect(described_class::CONSUMER_GROUP - described_class::SHARE_GROUP)
        .to match_array(consumer_group_only)
    end

    it "expect share-only attributes to be exactly the share-specific ones" do
      expect(described_class::SHARE_GROUP - described_class::CONSUMER_GROUP)
        .to match_array(share_group_only)
    end
  end
end
