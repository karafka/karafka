# frozen_string_literal: true

RSpec.describe Karafka::Connection::Message do
  let(:topic) { rand.to_s }
  let(:content) { rand.to_s }
  let(:key) { nil }
  let(:offset) { rand(1000) }
  let(:partition) { rand(100) }
  let(:kafka_message) do
    Kafka::FetchedMessage.new(
      topic: topic,
      value: content,
      key: key,
      offset: offset,
      partition: partition
    )
  end

  subject(:message) { described_class.new(topic, kafka_message) }

  describe '.initialize' do
    it { expect(message.topic).to eq topic }
    it { expect(message.content).to eq content }
    it { expect(message.key).to eq key }
    it { expect(message.offset).to eq offset }
    it { expect(message.partition).to eq partition }
  end

  describe '.to_h' do
    subject(:casted_message) { described_class.new(topic, kafka_message).to_h }

    it { expect(casted_message[:topic]).to eq topic }
    it { expect(casted_message[:content]).to eq content }
    it { expect(casted_message[:key]).to eq key }
    it { expect(casted_message[:offset]).to eq offset }
    it { expect(casted_message[:partition]).to eq partition }
  end
end
