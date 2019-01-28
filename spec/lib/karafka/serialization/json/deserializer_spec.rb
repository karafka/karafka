# frozen_string_literal: true

RSpec.describe Karafka::Serialization::Json::Deserializer do
  subject(:deserializer) { described_class.new }

  describe '.call' do
    context 'when we can deserialize given content' do
      let(:content_source) { { rand.to_s => rand.to_s } }
      let(:content) { content_source.to_json }

      it 'expect to deserialize' do
        expect(deserializer.call(content)).to eq content_source
      end
    end

    context 'when content is malformatted' do
      let(:content) { 'abc' }

      it 'expect to raise with Karafka internal deserializing error' do
        expect { deserializer.call(content) }.to raise_error(::Karafka::Errors::DeserializationError)
      end
    end
  end
end
