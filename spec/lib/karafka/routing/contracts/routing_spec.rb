# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(routing) }

  before { Karafka::App.config.strict_declarative_topics = true }

  after { Karafka::App.config.strict_declarative_topics = false }

  context "when there are no routes" do
    let(:routing) { [] }

    it { expect(check).to be_success }
  end

  context "when there are topics routes with declaratives without DLQ" do
    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: false },
              declaratives: { active: true }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end

  context "when there are topics routes with inactive declaratives" do
    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: false },
              declaratives: { active: false }
            }
          ]
        }
      ]
    end

    it { expect(check).not_to be_success }
  end

  context "when there are pattern topics routes with inactive declaratives" do
    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: true },
              dead_letter_queue: { active: false },
              declaratives: { active: false }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end

  context "when there are topics routes with DLQ without declaratives" do
    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: true, topic: "dlq" },
              declaratives: { active: false }
            }
          ]
        }
      ]
    end

    it { expect(check).not_to be_success }
  end

  context "when there are topics routes with DLQ with declaratives" do
    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: true, topic: "dlq" },
              declaratives: { active: true }
            },
            {
              name: "dlq",
              patterns: { active: false },
              dead_letter_queue: { active: false },
              declaratives: { active: true }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end

  context "when there are pattern topics routes with DLQ without declaratives" do
    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: true },
              dead_letter_queue: { active: true, topic: "dlq" },
              declaratives: { active: false }
            },
            {
              name: "dlq",
              patterns: { active: false },
              dead_letter_queue: { active: false },
              declaratives: { active: true }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end

  context "when there are share-group topics without a declaration" do
    let(:routing) { [{ topics: [{ name: "share-topic" }] }] }

    it { expect(check).not_to be_success }
  end

  context "when there are share-group topics with an inactive declaration" do
    let(:routing) { [{ topics: [{ name: "share-topic" }] }] }

    before { Karafka::App.declaratives.repository.find_or_create("share-topic").active(false) }

    it { expect(check).not_to be_success }
  end

  context "when there are share-group topics with an active declaration" do
    let(:routing) { [{ topics: [{ name: "share-topic" }] }] }

    before { Karafka::App.declaratives.repository.find_or_create("share-topic") }

    it { expect(check).to be_success }
  end

  context "when there are share-group topics without a declaration but not strict" do
    before { Karafka::App.config.strict_declarative_topics = false }

    let(:routing) { [{ topics: [{ name: "share-topic" }] }] }

    it { expect(check).to be_success }
  end

  context "when there are topics routes with inactive declaratives but not strict" do
    before { Karafka::App.config.strict_declarative_topics = false }

    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: false },
              declaratives: { active: false }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end
end
