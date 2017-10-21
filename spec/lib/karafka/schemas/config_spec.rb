# frozen_string_literal: true

RSpec.describe Karafka::Schemas::Config do
  let(:schema) { described_class }

  let(:config) do
    {
      client_id: 'name',
      topic_mapper: Karafka::Routing::TopicMapper
    }
  end

  context 'config is valid' do
    it { expect(schema.call(config)).to be_success }
  end

  context 'client_id validator' do
    it 'client_id is nil' do
      config[:client_id] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'client_id is not a string' do
      config[:client_id] = 2
      expect(schema.call(config)).not_to be_success
    end
  end
end
