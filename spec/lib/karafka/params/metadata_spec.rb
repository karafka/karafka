# frozen_string_literal: true

RSpec.describe Karafka::Params::Metadata do
  subject(:metadata) { described_class.new }

  let(:rand_value) { rand }

  %w[
    create_time
    headers
    is_control_record
    key
    offset
    deserializer
    partition
    receive_time
    topic
  ].each do |attribute|
    describe "##{attribute}" do
      before { metadata[attribute] = rand_value }

      it { expect(metadata.public_send(attribute)).to eq rand_value }
    end
  end
end
