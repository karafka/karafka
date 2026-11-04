# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_share_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe "#dead_letter_queue" do
    context "when not configured" do
      it { expect(topic.dead_letter_queue.active?).to be(false) }
      it { expect(topic.dead_letter_queue.max_retries).to eq(3) }
      it { expect(topic.dead_letter_queue.dispatch_method).to eq(:produce_async) }
    end

    context "when configured" do
      before do
        topic.dead_letter_queue(topic: "dlq", max_retries: 1, dispatch_method: :produce_sync)
      end

      it { expect(topic.dead_letter_queue.active?).to be(true) }
      it { expect(topic.dead_letter_queue.topic).to eq("dlq") }
      it { expect(topic.dead_letter_queue.max_retries).to eq(1) }
      it { expect(topic.dead_letter_queue.dispatch_method).to eq(:produce_sync) }
    end
  end

  describe "#dead_letter_queue?" do
    context "when topic is set" do
      before { topic.dead_letter_queue(topic: "dlq") }

      it { expect(topic.dead_letter_queue?).to be(true) }
    end

    context "when topic is not set" do
      it { expect(topic.dead_letter_queue?).to be(false) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:dead_letter_queue]).to eq(topic.dead_letter_queue.to_h) }
  end
end
