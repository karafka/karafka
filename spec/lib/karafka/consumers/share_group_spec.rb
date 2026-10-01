# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) { described_class.new }

  describe "hierarchy and introspection" do
    it { expect(described_class).to be < Karafka::Consumers::Base }
    it { expect(consumer).not_to be_a(Karafka::Consumers::ConsumerGroup) }

    it "expect Karafka::ShareConsumer to alias this class as the user-facing primitive" do
      expect(Karafka::ShareConsumer).to equal(described_class)
    end

    it "expect to report the share group type" do
      expect(consumer.group_type).to eq(:share)
      expect(consumer).to be_share_group
      expect(consumer).not_to be_consumer_group
    end
  end

  describe "the acknowledgement API" do
    let(:message) { build(:messages_message) }
    let(:client) do
      instance_double(
        Karafka::Connection::ShareGroups::Client,
        mark_as_accepted: nil,
        mark_as_released: nil,
        mark_as_rejected: nil,
        commit!: nil
      )
    end

    before { consumer.client = client }

    describe "async (flushed on the next commit)" do
      it "expect #mark_as_accepted to accept the message via the client" do
        expect(client).to receive(:mark_as_accepted).with(message)
        consumer.mark_as_accepted(message)
      end

      it "expect #mark_as_released to release the message via the client" do
        expect(client).to receive(:mark_as_released).with(message)
        consumer.mark_as_released(message)
      end

      it "expect #mark_as_rejected to reject the message via the client" do
        expect(client).to receive(:mark_as_rejected).with(message)
        consumer.mark_as_rejected(message)
      end

      it "expect to return true when acknowledging" do
        expect(consumer.mark_as_accepted(message)).to be(true)
      end
    end

    describe "acknowledging the same message twice" do
      before { consumer.mark_as_accepted(message) }

      it "expect not to acknowledge it again and to return false" do
        expect(consumer.mark_as_released(message)).to be(false)
        expect(consumer.mark_as_rejected!(message)).to be(false)
        expect(client).not_to have_received(:mark_as_released)
        expect(client).not_to have_received(:mark_as_rejected)
        expect(client).not_to have_received(:commit!)
      end

      it "expect to allow acknowledging it again in the next batch" do
        consumer.send(:acknowledgements_tracker).clear

        expect(consumer.mark_as_released(message)).to be(true)
      end
    end

    describe "sync (flushed immediately)" do
      it "expect #mark_as_accepted! to accept and commit synchronously" do
        expect(client).to receive(:mark_as_accepted).with(message).ordered
        expect(client).to receive(:commit!).ordered
        consumer.mark_as_accepted!(message)
      end

      it "expect #mark_as_released! to release and commit synchronously" do
        expect(client).to receive(:mark_as_released).with(message).ordered
        expect(client).to receive(:commit!).ordered
        consumer.mark_as_released!(message)
      end

      it "expect #mark_as_rejected! to reject and commit synchronously" do
        expect(client).to receive(:mark_as_rejected).with(message).ordered
        expect(client).to receive(:commit!).ordered
        consumer.mark_as_rejected!(message)
      end
    end
  end

  describe "not-yet-available API" do
    # Delayed release and lock extension (RENEW) are Pro/future features and are intentionally
    # absent from the core share consumer rather than present as raising stubs.
    %i[extend_lock! renew].each do |method_name|
      it "expect not to respond to :#{method_name}" do
        expect(consumer).not_to respond_to(method_name)
      end
    end
  end

  describe "consumer-group only API" do
    # Share consumers acknowledge individual records instead of committing partition offsets, so
    # the consumer-group offset/pause/seek/eof/revocation API must not be present.
    %i[
      pause resume seek seek_offset eofed? revoked? retrying? attempt retry_after_pause
      on_eofed on_revoked
    ].each do |method_name|
      it "expect not to respond to :#{method_name}" do
        expect(consumer).not_to respond_to(method_name)
      end
    end
  end

  describe "#consume" do
    it "expect the inherited stub to raise NotImplementedError" do
      expect { consumer.send(:consume) }.to raise_error(NotImplementedError)
    end
  end
end
