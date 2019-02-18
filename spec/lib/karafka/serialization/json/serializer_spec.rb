# frozen_string_literal: true

RSpec.describe Karafka::Serialization::Json::Serializer do
  subject(:serializer) { described_class.new }

  describe '.call' do
    context 'when content is a string' do
      let(:content) { rand.to_s }

      it 'expect not to do anything' do
        expect(serializer.call(content)).to eq content
      end
    end

    context 'when content can be serialized with #to_json' do
      let(:content) { { rand.to_s => rand.to_s } }

      it 'expect to serialize it that way' do
        expect(serializer.call(content)).to eq content.to_json
      end
    end

    context 'when content cannot be serialized with #to_json' do
      let(:content) { instance_double(Class, respond_to?: false) }

      it 'expect to raise serialization error' do
        expect { serializer.call(content) }.to raise_error(::Karafka::Errors::SerializationError)
      end
    end
  end
end
