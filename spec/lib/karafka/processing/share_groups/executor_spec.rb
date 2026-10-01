# frozen_string_literal: true

RSpec.describe_current do
  subject(:executor) { described_class.new(group_id, client, coordinator) }

  let(:group_id) { SecureRandom.hex(6) }
  let(:client) { instance_double(Karafka::Connection::ShareGroups::Client, settle: nil) }
  let(:topic) { build(:routing_share_topic) }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(topic) }
  let(:messages) { [build(:messages_message)] }
  let(:consumed) { [] }

  let(:consumer_class) do
    collector = consumed

    Class.new(Karafka::ShareConsumer) do
      define_method(:consume) do
        collector.concat(messages.to_a)
      end
    end
  end

  before do
    allow(topic).to receive_messages(consumer_class: consumer_class, consumer_persistence: true)
  end

  describe "the consume flow" do
    before do
      coordinator.start(messages)
      coordinator.increment(:consume)

      executor.before_schedule_consume(messages)
      executor.before_consume
      executor.consume
      executor.after_consume
    end

    it "runs the user consume code" do
      expect(consumed.size).to eq(1)
    end

    it "marks the coordinator successful and settles the unacknowledged records" do
      expect(coordinator.success?).to be(true)
      expect(client).to have_received(:settle).with(kind_of(Karafka::Messages::Messages), :release)
    end

    it "exposes the topic and a batch-level partition of -1" do
      expect(executor.topic).to eq(topic)
      expect(executor.partition).to eq(-1)
    end
  end

  describe "#shutdown" do
    it "is a no-op when no consumer was ever built" do
      expect { executor.shutdown }.not_to raise_error
    end
  end
end
