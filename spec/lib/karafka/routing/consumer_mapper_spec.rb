# frozen_string_literal: true

RSpec.describe Karafka::Routing::ConsumerMapper do
  subject(:mapper) { described_class }

  let(:raw_consumer_group_name) { rand.to_s }

  describe '#call' do
    let(:default_mapped_group) do
      [
        Karafka::App.config.client_id.to_s.underscore,
        raw_consumer_group_name
      ].join('_')
    end

    it { expect(mapper.call(raw_consumer_group_name)).to eq default_mapped_group }
  end
end
