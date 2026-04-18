# frozen_string_literal: true

RSpec.describe Karafka::Declaratives::Repository do
  subject(:repository) { described_class.new }

  describe "#find_or_create" do
    it "creates a new topic declaration" do
      topic = repository.find_or_create(:orders)
      expect(topic).to be_a(Karafka::Declaratives::Topic)
      expect(topic.name).to eq("orders")
    end

    it "returns the same declaration for the same name" do
      first = repository.find_or_create(:orders)
      second = repository.find_or_create(:orders)
      expect(first).to equal(second)
    end

    it "handles string and symbol names as equivalent" do
      sym = repository.find_or_create(:orders)
      str = repository.find_or_create("orders")
      expect(sym).to equal(str)
    end
  end

  describe "#active_topics" do
    before do
      repository.find_or_create(:active_topic)
      inactive = repository.find_or_create(:inactive_topic)
      inactive.active(false)
    end

    it "returns only active topics" do
      topics = repository.active_topics
      expect(topics.size).to eq(1)
      expect(topics.first.name).to eq("active_topic")
    end
  end

  describe "#find" do
    it "returns nil for unknown topics" do
      expect(repository.find(:unknown)).to be_nil
    end

    it "returns the topic if it exists" do
      repository.find_or_create(:orders)
      expect(repository.find(:orders)).to be_a(Karafka::Declaratives::Topic)
    end
  end

  describe "#each" do
    before do
      repository.find_or_create(:topic_a)
      repository.find_or_create(:topic_b)
    end

    it "yields each topic" do
      names = []
      repository.each { |topic| names << topic.name }
      expect(names).to contain_exactly("topic_a", "topic_b")
    end
  end

  describe "#size" do
    it "returns 0 for empty repository" do
      expect(repository.size).to eq(0)
    end

    it "returns the number of declarations" do
      repository.find_or_create(:a)
      repository.find_or_create(:b)
      expect(repository.size).to eq(2)
    end
  end

  describe "#empty?" do
    it "returns true when empty" do
      expect(repository.empty?).to be(true)
    end

    it "returns false when not empty" do
      repository.find_or_create(:a)
      expect(repository.empty?).to be(false)
    end
  end

  describe "#clear" do
    it "removes all declarations" do
      repository.find_or_create(:a)
      repository.clear
      expect(repository.empty?).to be(true)
    end
  end
end
