# frozen_string_literal: true

RSpec.describe_current do
  subject(:messages) do
    Karafka::Messages::Builders::Messages.call(messages_array, topic, 0, received_at)
  end

  let(:deserialized_payload) { { rand.to_s => rand.to_s } }
  let(:serialized_payload) { deserialized_payload.to_json }
  let(:topic) { build(:routing_topic) }
  let(:message1) { build(:messages_message, raw_payload: serialized_payload) }
  let(:message2) { build(:messages_message, raw_payload: serialized_payload) }
  let(:messages_array) { [message1, message2] }
  let(:received_at) { Time.now }

  describe '#to_a' do
    it 'expect not to deserialize data and return raw messages' do
      expect(messages.to_a.first.deserialized?).to be(false)
    end

    it 'expect to return copy of the underlying array' do
      ar1 = messages.to_a
      ar2 = messages.to_a

      expect(ar1).not_to be(ar2)
    end
  end

  describe '#deserialize!' do
    it 'expect to deserialize all the messages and return deserialized' do
      messages.deserialize!
      messages.to_a.each { |params| expect(params.deserialized?).to be(true) }
    end
  end

  describe '#each' do
    it 'expect not to deserialize each at a time' do
      messages.each_with_index do |params, index|
        expect(params.deserialized?).to be(false)
        next if index > 0

        expect(messages.to_a[index + 1].deserialized?).to be(false)
      end
    end
  end

  describe '#payloads' do
    it 'expect to return deserialized payloads from messages within a batch' do
      expect(messages.payloads).to eq [deserialized_payload, deserialized_payload]
    end

    context 'when payloads were used for the first time' do
      before { messages.payloads }

      it 'expect to mark as serialized all the messages inside the batch' do
        expect(messages.to_a.all?(&:deserialized?)).to be(true)
      end
    end
  end

  describe '#raw_payloads' do
    it 'expect to return raw payloads from messages within a batch' do
      expect(messages.raw_payloads).to eq [serialized_payload, serialized_payload]
    end

    context 'when payloads were used for the first time' do
      before { messages.payloads }

      it 'expect to still keep the raw references' do
        expect(messages.raw_payloads).to eq [serialized_payload, serialized_payload]
      end
    end
  end

  describe '#first' do
    it 'expect to return first element without deserializing' do
      expect(messages.first).to eq messages.to_a[0]
      expect(messages.first.deserialized?).to be(false)
    end
  end

  describe '#last' do
    it 'expect to return last element without deserializing' do
      expect(messages.last).to eq messages.to_a[-1]
      expect(messages.last.deserialized?).to be(false)
    end
  end

  describe '#size' do
    it { expect(messages.size).to eq messages.to_a.size }
  end

  describe '#empty?' do
    it { expect(messages.empty?).to be(false) }
  end
end
