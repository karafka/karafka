# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe "#inline_insights" do
    context "when we use inline_insights without any arguments" do
      it "expect to initialize with defaults" do
        expect(topic.inline_insights.active?).to be(false)
      end
    end

    context "when we use inline_insights with active status" do
      it "expect to use proper active status" do
        topic.inline_insights(true)
        expect(topic.inline_insights.active?).to be(true)
      end
    end

    context "when we use inline_insights multiple times with different values" do
      it "expect to use proper active status" do
        topic.inline_insights(true)
        topic.inline_insights(false)
        expect(topic.inline_insights.active?).to be(true)
      end
    end
  end

  describe "#inline_insights?" do
    context "when active" do
      before { topic.inline_insights(true) }

      it { expect(topic.inline_insights?).to be(true) }
    end

    context "when not active" do
      before { topic.inline_insights(false) }

      it { expect(topic.inline_insights?).to be(false) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:inline_insights]).to eq(topic.inline_insights.to_h) }
  end
end
