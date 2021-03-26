# frozen_string_literal: true

RSpec.describe Karafka::Messages::Metadata do
  subject(:metadata) { described_class.new }

  let(:rand_value) { rand }

  %w[
    timestamp
    headers
    key
    offset
    deserializer
    partition
    received_at
    topic
  ].each do |attribute|
    describe "##{attribute}" do
      before { metadata[attribute] = rand_value }

      it { expect(metadata.public_send(attribute)).to eq rand_value }
    end
  end
end
