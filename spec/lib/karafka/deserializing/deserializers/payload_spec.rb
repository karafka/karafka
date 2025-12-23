# frozen_string_literal: true

RSpec.describe_current do
  subject(:deserializer) { described_class.new }

  let(:params) do
    metadata = Karafka::Messages::Metadata.new
    metadata['deserializers'] = Karafka::Routing::Features::Deserializing::Config.new(
      payload: deserializer
    )

    Karafka::Messages::Message.new(
      raw_payload,
      metadata
    )
  end

  describe '#initialize' do
    it 'inherits from Base' do
      expect(described_class.superclass).to eq(Karafka::Deserializing::Deserializers::Base)
    end

    it 'is frozen for Ractor shareability' do
      expect(deserializer).to be_frozen
    end
  end

  describe '#call' do
    context 'when deserializing valid JSON raw_payload' do
      let(:content_source) { { rand.to_s => rand.to_s } }
      let(:raw_payload) { content_source.to_json }

      it 'expect to deserialize' do
        expect(params.payload).to eq content_source
      end
    end

    context 'when raw_payload is malformatted' do
      let(:raw_payload) { 'abc' }
      let(:expected_error) { JSON::ParserError }

      it 'expect to raise with Karafka internal deserializing error' do
        expect { params.payload }.to raise_error(expected_error)
      end
    end

    context 'when we deserialize nil that can be used for log compaction' do
      let(:content_source) { nil }
      let(:raw_payload) { nil }

      it 'expect to deserialize' do
        expect(params.payload).to eq content_source
      end
    end
  end
end
