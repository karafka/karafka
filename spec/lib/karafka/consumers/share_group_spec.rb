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
    let(:message) { instance_double(Karafka::Messages::Message) }
    let(:client) { instance_double(Karafka::Connection::ShareGroups::Client) }

    before { consumer.client = client }

    describe "async (flushed on the next commit)" do
      it "expect #mark_consumed to accept the message via the client" do
        expect(client).to receive(:mark_as_consumed).with(message)
        consumer.mark_consumed(message)
      end

      it "expect #mark_as_consumed to be an alias of #mark_consumed" do
        expect(client).to receive(:mark_as_consumed).with(message)
        consumer.mark_as_consumed(message)
      end

      it "expect #mark_released to release the message via the client" do
        expect(client).to receive(:mark_as_released).with(message)
        consumer.mark_released(message)
      end

      it "expect #mark_rejected to reject the message via the client" do
        expect(client).to receive(:mark_as_rejected).with(message)
        consumer.mark_rejected(message)
      end
    end

    describe "sync (flushed immediately)" do
      it "expect #mark_consumed! to accept and commit synchronously" do
        expect(client).to receive(:mark_as_consumed).with(message).ordered
        expect(client).to receive(:commit!).ordered
        consumer.mark_consumed!(message)
      end

      it "expect #mark_as_consumed! to be an alias of #mark_consumed!" do
        allow(client).to receive(:mark_as_consumed)
        expect(client).to receive(:commit!)
        consumer.mark_as_consumed!(message)
      end

      it "expect #mark_released! to release and commit synchronously" do
        expect(client).to receive(:mark_as_released).with(message).ordered
        expect(client).to receive(:commit!).ordered
        consumer.mark_released!(message)
      end

      it "expect #mark_rejected! to reject and commit synchronously" do
        expect(client).to receive(:mark_as_rejected).with(message).ordered
        expect(client).to receive(:commit!).ordered
        consumer.mark_rejected!(message)
      end
    end

    it "expect #mark_released with a delay to raise NotImplementedError (not implemented yet)" do
      expect { consumer.mark_released(message, delay: 1_000) }.to raise_error(NotImplementedError)
    end

    it "expect #extend_lock! to raise NotImplementedError (not implemented yet)" do
      expect { consumer.extend_lock!(message) }.to raise_error(NotImplementedError)
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
