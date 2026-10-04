# frozen_string_literal: true

RSpec.describe_current do
  subject(:validation) { described_class.new.call(config) }

  let(:config) do
    {
      dead_letter_queue: {
        active: true,
        max_retries: 3,
        topic: "dlq",
        dispatch_method: :produce_async
      }
    }
  end

  context "when config is valid" do
    it { expect(validation).to be_success }
  end

  context "when topic is false (reject without dispatch)" do
    before { config[:dead_letter_queue][:topic] = false }

    it { expect(validation).to be_success }
  end

  context "when topic has an invalid name" do
    before { config[:dead_letter_queue][:topic] = "invalid topic" }

    it { expect(validation).not_to be_success }
  end

  context "when not active and without a topic" do
    before do
      config[:dead_letter_queue][:active] = false
      config[:dead_letter_queue][:topic] = nil
    end

    it { expect(validation).to be_success }
  end

  context "when max_retries is negative" do
    before { config[:dead_letter_queue][:max_retries] = -1 }

    it { expect(validation).not_to be_success }
  end

  context "when dispatch_method is not supported" do
    before { config[:dead_letter_queue][:dispatch_method] = :produce }

    it { expect(validation).not_to be_success }
  end
end
