# frozen_string_literal: true

RSpec.describe_current do
  describe "#TOPIC_REGEXP" do
    subject(:match) { input.match? described_class::TOPIC_REGEXP }

    context "when topic name is valid" do
      let(:input) { "name" }

      it { is_expected.to be(true) }
    end

    context "when topic name is invalid" do
      let(:input) { "$%^&*" }

      it { is_expected.to be(false) }
    end

    context "when only the first line is valid" do
      let(:input) { "name\n$%^&*" }

      it { is_expected.to be(false) }
    end

    context "when it ends with a new line" do
      let(:input) { "name\n" }

      it { is_expected.to be(false) }
    end
  end

  describe "#TOPIC_NAME_REGEXP" do
    subject(:match) { input.match? described_class::TOPIC_NAME_REGEXP }

    context "when topic name is valid" do
      let(:input) { "my-topic_1.events" }

      it { is_expected.to be(true) }
    end

    context "when topic name is invalid" do
      let(:input) { "$%^&*" }

      it { is_expected.to be(false) }
    end

    context "when only the first line is valid" do
      let(:input) { "name\n$%^&*" }

      it { is_expected.to be(false) }
    end

    context "when it is empty" do
      let(:input) { "" }

      it { is_expected.to be(false) }
    end

    context "when it is a dot" do
      let(:input) { "." }

      it { is_expected.to be(false) }
    end

    context "when it is a double dot" do
      let(:input) { ".." }

      it { is_expected.to be(false) }
    end

    context "when it starts with dots" do
      let(:input) { "..name" }

      it { is_expected.to be(true) }
    end

    context "when it is 249 characters long" do
      let(:input) { "a" * 249 }

      it { is_expected.to be(true) }
    end

    context "when it is longer than 249 characters" do
      let(:input) { "a" * 250 }

      it { is_expected.to be(false) }
    end
  end
end
