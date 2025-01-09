# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:parsing) { described_class.new.call(message) }

  let(:message) { instance_double(Karafka::Messages::Message) }
  let(:raw_payload) { '{"key":"value"}' }
  let(:headers) { {} }

  before do
    allow(message).to receive_messages(
      raw_payload: raw_payload,
      headers: headers
    )
  end

  let(:raw_payload) { Zlib::Deflate.deflate('{"key":"value"}') }

  context 'when JSON is parsed successfully' do
    it 'returns a hash' do
      expect(parsing).to be_a(Hash)
    end

    it 'returns a hash with symbolized keys' do
      expect(parsing.keys.all? { |key| key.is_a?(Symbol) }).to be(true)
    end

    it 'returns a hash with expected values' do
      expect(parsing).to eq({ key: 'value' })
    end
  end

  context 'when JSON parsing fails' do
    let(:raw_payload) { Zlib::Deflate.deflate('invalid json') }

    it 'raises a JSON::ParserError' do
      expect { parsing }.to raise_error(JSON::ParserError)
    end
  end

  context 'when data is not compressed' do
    let(:raw_payload) { 'not compressed' }

    it 'raises a Zlib::DataError' do
      expect { parsing }.to raise_error(Zlib::DataError)
    end
  end
end
