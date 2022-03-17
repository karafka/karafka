# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { described_class.new(name, consumer_group) }

  let(:consumer_group) { instance_double(Karafka::Routing::ConsumerGroup, id: group_id) }
  let(:name) { :test }
  let(:group_id) { rand.to_s }
  let(:consumer) { Class.new(Karafka::BaseConsumer) }

  before { topic.consumer = consumer }

  describe '#name' do
    it 'expect to return stringified topic' do
      expect(topic.name).to eq name.to_s
    end
  end

  describe '#consumer_group' do
    it { expect(topic.consumer_group).to eq consumer_group }
  end

  describe '#id' do
    it { expect(topic.id).to eq "#{consumer_group.id}_#{name}" }
  end

  describe '#deserializer=' do
    let(:deserializer) { double }

    it { expect { topic.deserializer = deserializer }.not_to raise_error }
  end

  describe '#deserializer' do
    before { topic.deserializer = deserializer }

    context 'when deserializer is not set' do
      let(:deserializer) { nil }

      it 'expect to use default one' do
        expect(topic.deserializer).to be_a Karafka::Serialization::Json::Deserializer
      end
    end

    context 'when deserializer is set' do
      let(:deserializer) { double }

      it { expect(topic.deserializer).to eq deserializer }
    end
  end

  %w[kafka manual_offset_management deserializer max_messages max_wait_time].each do |attribute|
    it { expect(topic).to respond_to(attribute) }
    it { expect(topic).to respond_to(:"#{attribute}=") }
  end

  describe '#to_h' do
    let(:expected_keys) do
      %i[kafka deserializer manual_offset_management max_messages max_wait_time initial_offset] +
        %i[id name consumer consumer_group_id]
    end

    it 'expect to contain all the topic attrs plus some inherited' do
      expect(topic.to_h.keys).to eq(expected_keys)
    end
  end
end
