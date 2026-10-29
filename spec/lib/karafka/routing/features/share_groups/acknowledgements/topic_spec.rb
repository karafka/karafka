# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_share_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe "#acknowledgements" do
    context "when not configured" do
      it "releases unacknowledged records by default" do
        expect(topic.acknowledgements.unacknowledged).to eq(:release)
      end
    end

    context "when configured" do
      before { topic.acknowledgements(unacknowledged: :accept) }

      it { expect(topic.acknowledgements.unacknowledged).to eq(:accept) }
    end
  end

  describe "#acknowledgements?" do
    it { expect(topic.acknowledgements?).to be(true) }
  end

  describe "#to_h" do
    it "includes acknowledgements in the topic hash" do
      expect(topic.to_h[:acknowledgements]).to eq(topic.acknowledgements.to_h)
    end
  end
end
