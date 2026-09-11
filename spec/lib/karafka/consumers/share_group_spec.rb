# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) { described_class.new }

  describe "hierarchy and introspection" do
    it { expect(described_class).to be < Karafka::Consumers::Base }
    it { expect(consumer).not_to be_a(Karafka::Consumers::ConsumerGroup) }

    it "expect to report the share group type" do
      expect(consumer.group_type).to eq(:share)
      expect(consumer).to be_share_group
      expect(consumer).not_to be_consumer_group
    end
  end

  describe "the not-yet-implemented acknowledgement API" do
    let(:message) { instance_double(Karafka::Messages::Message) }

    it "expect #mark_accepted to raise NotImplementedError" do
      expect { consumer.mark_accepted(message) }.to raise_error(NotImplementedError)
    end

    it "expect #mark_released to raise NotImplementedError" do
      expect { consumer.mark_released(message) }.to raise_error(NotImplementedError)
    end

    it "expect #mark_released with a delay to raise NotImplementedError" do
      expect { consumer.mark_released(message, delay: 1_000) }.to raise_error(NotImplementedError)
    end

    it "expect #mark_rejected to raise NotImplementedError" do
      expect { consumer.mark_rejected(message) }.to raise_error(NotImplementedError)
    end

    it "expect #extend_lock! to raise NotImplementedError" do
      expect { consumer.extend_lock!(message) }.to raise_error(NotImplementedError)
    end
  end

  describe "consumer-group only API" do
    # Share consumers acknowledge individual records instead of committing partition offsets, so
    # the consumer-group offset/pause/seek/eof/revocation API must not be present.
    %i[
      pause resume seek seek_offset eofed? revoked? retrying? attempt retry_after_pause
      on_consume on_after_consume on_eofed on_revoked
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
