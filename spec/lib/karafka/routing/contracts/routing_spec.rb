# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(routing) }

  before { Karafka::App.config.strict_declarative_topics = true }

  after { Karafka::App.config.strict_declarative_topics = false }

  # Declarative definitions live independently of routing in the declaratives repository.
  # A routed topic counts as declaratively managed when it has an active declaration there.
  let(:declare) do
    lambda do |name, active: true|
      Karafka::App.declaratives.draw do
        topic(name) { active(active) }
      end
    end
  end

  context "when there are no routes" do
    let(:routing) { [] }

    it { expect(check).to be_success }
  end

  context "when there are topics routes with declaratives without DLQ" do
    before { declare.call("topic") }

    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: false }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end

  context "when there are topics routes with inactive declaratives" do
    before { declare.call("topic", active: false) }

    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: false }
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
              dead_letter_queue: { active: false }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end

  context "when there are topics routes with DLQ without declaratives" do
    before { declare.call("topic") }

    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: true, topic: "dlq" }
            }
          ]
        }
      ]
    end

    it { expect(check).not_to be_success }
  end

  context "when there are topics routes with DLQ with declaratives" do
    before do
      declare.call("topic")
      declare.call("dlq")
    end

    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: false },
              dead_letter_queue: { active: true, topic: "dlq" }
            },
            {
              name: "dlq",
              patterns: { active: false },
              dead_letter_queue: { active: false }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end

  context "when there are pattern topics routes with DLQ without declaratives" do
    before { declare.call("dlq") }

    let(:routing) do
      [
        {
          topics: [
            {
              name: "topic",
              patterns: { active: true },
              dead_letter_queue: { active: true, topic: "dlq" }
            },
            {
              name: "dlq",
              patterns: { active: false },
              dead_letter_queue: { active: false }
            }
          ]
        }
      ]
    end

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
              dead_letter_queue: { active: false }
            }
          ]
        }
      ]
    end

    it { expect(check).to be_success }
  end
end
