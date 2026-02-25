# frozen_string_literal: true

RSpec.describe_current do
  subject(:reset_topics) { described_class.new }

  describe "#call" do
    let(:topics_delete) { instance_double(Karafka::Cli::Topics::Delete, call: true) }
    let(:topics_create) { instance_double(Karafka::Cli::Topics::Create, call: true) }

    before do
      allow(Karafka::Cli::Topics::Delete).to receive(:new).and_return(topics_delete)
      allow(Karafka::Cli::Topics::Create).to receive(:new).and_return(topics_create)

      allow(reset_topics).to receive(:wait) # Stubbing the wait method to prevent delays in tests
    end

    it "calls the delete and create operations in sequence with a wait in between" do
      expect(reset_topics.call).to be(true)

      expect(Karafka::Cli::Topics::Delete).to have_received(:new).once
      expect(topics_delete).to have_received(:call).once
      expect(reset_topics).to have_received(:wait).once
      expect(Karafka::Cli::Topics::Create).to have_received(:new).once
      expect(topics_create).to have_received(:call).once
    end
  end
end
