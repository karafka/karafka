# frozen_string_literal: true

RSpec.describe Karafka::Schemas::Config do
  let(:schema) { described_class }

  let(:config) do
    {
      client_id: 'name',
      topic_mapper: Karafka::Routing::TopicMapper
    }
  end

  context 'when config is valid' do
    it { expect(schema.call(config)).to be_success }
  end

  context 'when we validate client_id' do
    context 'when client_id is nil' do
      before { config[:client_id] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when client_id is not a string' do
      before { config[:client_id] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end
end
