# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe "#declaratives" do
    context "when we use declaratives without any arguments without config exec" do
      it { expect(topic.declaratives.active?).to be(true) }
      it { expect(topic.declaratives.partitions).to eq(1) }
      it { expect(topic.declaratives.replication_factor).to eq(1) }
      it { expect(topic.declaratives.details).to eq({}) }
    end

    context "when we use declaratives with custom number of partitions" do
      before { topic.config(partitions: 5) }

      it { expect(topic.declaratives.partitions).to eq(5) }
    end

    context "when we use declaratives with custom replication factor" do
      before { topic.config(replication_factor: 5) }

      it { expect(topic.declaratives.replication_factor).to eq(5) }
    end

    context "when we use declaratives with other custom settings" do
      before { topic.config("cleanup.policy": "compact") }

      it { expect(topic.declaratives.details[:"cleanup.policy"]).to eq("compact") }
    end
  end

  describe "#declaratives?" do
    it "expect to always be active" do
      expect(topic.declaratives?).to be(true)
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:declaratives]).to eq(topic.declaratives.to_h) }

    context "with custom config" do
      before { topic.config(partitions: 10, replication_factor: 3) }

      it "includes declaratives hash in to_h output" do
        expect(topic.to_h[:declaratives]).to eq(
          active: true,
          partitions: 10,
          replication_factor: 3,
          details: {}
        )
      end
    end
  end

  describe "repository integration" do
    context "when config is called" do
      before { topic.config(partitions: 5, replication_factor: 3) }

      it "registers the topic in the declaratives repository" do
        declaration = Karafka::App.declaratives.find_topic(topic.name)
        expect(declaration).not_to be_nil
        expect(declaration.partitions).to eq(5)
        expect(declaration.replication_factor).to eq(3)
      end

      it "returns the same object via topic.declaratives" do
        declaration = Karafka::App.declaratives.find_topic(topic.name)
        expect(topic.declaratives).to equal(declaration)
      end
    end

    context "when config has details" do
      before { topic.config("cleanup.policy": "compact", partitions: 10) }

      it "stores config details on the declaration" do
        declaration = Karafka::App.declaratives.find_topic(topic.name)
        expect(declaration.details).to eq("cleanup.policy": "compact")
        expect(declaration.partitions).to eq(10)
      end
    end

    context "when config sets active to false" do
      before { topic.config(active: false) }

      it "creates an inactive declaration" do
        declaration = Karafka::App.declaratives.find_topic(topic.name)
        expect(declaration.active?).to be(false)
      end

      it "is not included in active topics" do
        expect(Karafka::App.declaratives.topics).to be_empty
      end
    end
  end

  describe "||= semantics (first call wins)" do
    before { topic.config(partitions: 5) }

    it "ignores subsequent config calls" do
      topic.config(partitions: 99)
      expect(topic.declaratives.partitions).to eq(5)
    end
  end
end
