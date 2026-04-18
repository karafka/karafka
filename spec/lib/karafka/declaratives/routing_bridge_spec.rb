# frozen_string_literal: true

RSpec.describe "Declaratives routing bridge" do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend(
        Karafka::Routing::Features::Declaratives::Topic
      )
    end
  end

  after { Karafka::App.declaratives.repository.clear }

  describe "routing config(...) creates declaration in repository" do
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

  describe "routing config(...) with details" do
    before { topic.config("cleanup.policy": "compact", partitions: 10) }

    it "stores config details on the declaration" do
      declaration = Karafka::App.declaratives.find_topic(topic.name)
      expect(declaration.details).to eq("cleanup.policy": "compact")
      expect(declaration.partitions).to eq(10)
    end
  end

  describe "routing config(active: false)" do
    before { topic.config(active: false) }

    it "creates an inactive declaration" do
      declaration = Karafka::App.declaratives.find_topic(topic.name)
      expect(declaration.active?).to be(false)
    end

    it "is not included in active_topics" do
      expect(Karafka::App.declaratives.topics).to be_empty
    end
  end

  describe "||= semantics (first call wins)" do
    before { topic.config(partitions: 5) }

    it "ignores subsequent config calls" do
      topic.config(partitions: 99)
      expect(topic.declaratives.partitions).to eq(5)
    end
  end

  describe "declaratives? predicate" do
    it "returns true by default" do
      expect(topic.declaratives?).to be(true)
    end

    context "when active is false" do
      before { topic.config(active: false) }

      it { expect(topic.declaratives?).to be(false) }
    end
  end

  describe "to_h includes declaratives" do
    before { topic.config(partitions: 10, replication_factor: 3) }

    it "includes declaratives hash in to_h output" do
      h = topic.to_h
      expect(h[:declaratives]).to eq(
        active: true,
        partitions: 10,
        replication_factor: 3,
        details: {}
      )
    end

    it "matches topic.declaratives.to_h" do
      expect(topic.to_h[:declaratives]).to eq(topic.declaratives.to_h)
    end
  end
end
