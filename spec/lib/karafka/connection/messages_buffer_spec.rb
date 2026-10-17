# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new(subscription_group) }

  let(:subscription_group) { build(:routing_subscription_group) }
  let(:topic_name) { subscription_group.topics.first.name }
  let(:raw_messages_buffer) { Karafka::Connection::RawMessagesBuffer.new }
  let(:raw_message1) { build(:kafka_fetched_message, topic: topic_name) }
  let(:raw_message2) { build(:kafka_fetched_message, topic: topic_name) }

  describe "#size, #empty?, #each and #present?" do
    context "when there are no messages" do
      it { expect(buffer.size).to eq(0) }
      it { expect(buffer.empty?).to be(true) }
      it { expect(buffer.present?(topic_name, 0)).to be(false) }

      it "expect not to yield anything" do
        expect { |block| buffer.each(&block) }.not_to yield_control
      end
    end

    context "when there are messages in the buffer" do
      let(:buffer_messages) do
        raw_messages_buffer << raw_message1
        raw_messages_buffer << raw_message2

        buffer.remap(raw_messages_buffer)

        messages = []
        buffer.each { |*args| messages << args }
        messages
      end

      before { buffer_messages }

      it { expect(buffer.size).to eq(2) }
      it { expect(buffer.empty?).to be(false) }
      it { expect(buffer_messages[0][0]).to eq(topic_name) }
      it { expect(buffer_messages[0][1]).to eq(0) }
      it { expect(buffer_messages[0][2][0]).to be_a(Karafka::Messages::Message) }
      it { expect(buffer_messages[0][2][1]).to be_a(Karafka::Messages::Message) }
      it { expect(buffer.present?(topic_name, 0)).to be(true) }
      it { expect(buffer.present?(topic_name, 10)).to be(false) }
    end
  end

  describe "#remap" do
    context "when buffer was empty" do
      before do
        raw_messages_buffer << raw_message1
        raw_messages_buffer << raw_message2
      end

      it "expect to add data to the buffer" do
        expect { buffer.remap(raw_messages_buffer) }.to change(buffer, :size).from(0).to(2)
      end
    end

    context "when messages were received at different moments" do
      let(:received_at) { [] }

      before do
        raw_messages_buffer << raw_message1
        raw_messages_buffer << raw_message2
        raw_messages_buffer.each { |*, times| received_at.concat(times) }
      end

      it "expect to assign to each message the moment it was received" do
        buffer.remap(raw_messages_buffer)

        buffer.each do |_, _, messages, _, _|
          expect(messages.map(&:received_at)).to eq(received_at)
        end
      end

      it "expect not to use the remap moment as the received moment" do
        sleep(0.01)
        remapped_at = Time.now
        buffer.remap(raw_messages_buffer)

        buffer.each do |_, _, messages, _, _|
          messages.each { |message| expect(message.received_at).to be < remapped_at }
        end
      end
    end

    context "when buffer was not empty" do
      let(:buffer_messages) do
        raw_messages_buffer << raw_message1

        buffer.remap(raw_messages_buffer)

        raw_messages_buffer.clear
        raw_messages_buffer << raw_message2

        buffer.remap(raw_messages_buffer)

        messages = []
        buffer.each { |*args| messages << args }
        messages
      end

      before { buffer_messages }

      it "expect to remove previous content before another remap" do
        expect { buffer.remap(raw_messages_buffer) }.not_to change(buffer, :size)
      end

      it { expect(buffer_messages[0][0]).to eq(topic_name) }
      it { expect(buffer_messages[0][1]).to eq(0) }
      it { expect(buffer_messages[0][2][0]).to be_a(Karafka::Messages::Message) }
      it { expect(buffer_messages[0][2][0].raw_payload).to eq(raw_message2.payload) }
      it { expect(buffer_messages[0][2][1]).to be_nil }
    end
  end
end
