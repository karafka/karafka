# frozen_string_literal: true

RSpec.describe_current do
  subject(:metadata) { described_class.new }

  let(:rand_value) { rand }

  %w[
    timestamp
    raw_headers
    raw_key
    offset
    deserializers
    partition
    received_at
    topic
  ].each do |attribute|
    describe "##{attribute}" do
      before { metadata[attribute] = rand_value }

      it { expect(metadata.public_send(attribute)).to eq rand_value }
    end
  end

  context 'deserialization' do
    subject(:metadata) do
      described_class.new(
        deserializers: deserializers,
        raw_key: raw_key,
        raw_headers: raw_headers
      )
    end

    let(:key_deserializer_proc) { ->(key) { "deserialized_#{key}" } }
    let(:raw_key) { 'test_key' }
    let(:raw_headers) { { 'content-type' => 'text/plain' } }

    let(:headers_deserializer_proc) do
      ->(headers) { headers.transform_keys(&:to_sym).transform_values(&:upcase) }
    end

    let(:deserializers) do
      double(
        key: key_deserializer_proc,
        headers: headers_deserializer_proc
      )
    end

    before do
      allow(key_deserializer_proc).to receive(:call).and_call_original
      allow(headers_deserializer_proc).to receive(:call).and_call_original
    end

    describe '#key' do
      it 'returns the deserialized key using the provided deserializer' do
        expect(metadata.key).to eq('deserialized_test_key')
      end

      it 'memoizes the deserialized key' do
        2.times { metadata.key }
        expect(key_deserializer_proc).to have_received(:call).once
      end
    end

    describe '#headers' do
      it 'returns the deserialized headers using the provided deserializer' do
        expect(metadata.headers).to eq({ 'content-type': 'TEXT/PLAIN' })
      end

      it 'memoizes the deserialized headers' do
        2.times { metadata.headers }
        expect(headers_deserializer_proc).to have_received(:call).once
      end
    end
  end
end
