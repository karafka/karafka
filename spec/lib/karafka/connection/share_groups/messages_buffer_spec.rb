# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new(subscription_group) }

  let(:subscription_group) { groups.first.subscription_groups.first }
  let(:groups) do
    Karafka::Routing::Builder.new.draw do
      share_group :group_name do
        topic :topic_name do
          consumer Class.new(Karafka::ShareConsumer)
        end
      end
    end
  end

  let(:raw_messages) do
    [[0, 1], [1, 1], [0, 2], [0, 3]].map do |partition, offset|
      instance_double(
        Rdkafka::ShareConsumer::Message,
        topic: "topic_name",
        partition: partition,
        offset: offset,
        timestamp: Time.now,
        headers: {},
        key: nil,
        payload: "payload",
        delivery_count: 2
      )
    end
  end

  it { expect(buffer).to be_empty }

  context "when remapped" do
    before { buffer.remap(raw_messages) }

    it { expect(buffer.size).to eq(4) }
    it { expect(buffer).not_to be_empty }

    it "expect to group built messages per topic partition without eof" do
      yielded = []
      buffer.each { |topic, partition, messages, eof| yielded << [topic, partition, messages.map(&:offset), eof] }

      expect(yielded).to contain_exactly(
        ["topic_name", 0, [1, 2, 3], false],
        ["topic_name", 1, [1], false]
      )
    end

    it "expect to expose the delivery count on built messages" do
      buffer.each { |_, _, messages| expect(messages.map(&:delivery_count).uniq).to eq([2]) }
    end
  end

  context "when remapped again" do
    before do
      buffer.remap(raw_messages)
      buffer.remap([])
    end

    it { expect(buffer).to be_empty }
  end
end
