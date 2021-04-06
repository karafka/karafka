# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { described_class.new(name, consumer_group) }

  let(:consumer_group) { instance_double(Karafka::Routing::ConsumerGroup, id: group_id) }
  let(:name) { :test }
  let(:group_id) { rand.to_s }
  let(:consumer) { Class.new(Karafka::BaseConsumer) }

  before { topic.consumer = consumer }

  describe '#build' do
    %w[
      kafka
      deserializer
      manual_offset_management
    ].each do |attr|
      context "for #{attr}" do
        let(:attr_value) { rand.to_s }

        it 'expect to invoke it and store' do
          # Some values are build from other, so we add at least once as they
          # might be used internally
          expect(topic).to receive(attr).and_return(attr_value).at_least(:once)
          topic.build
        end

        it { expect(topic.build).to be_a(described_class) }
      end
    end
  end

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

  %w[kafka manual_offset_management].each do |attribute|
    it { expect(topic).to respond_to(attribute) }
    it { expect(topic).to respond_to(:"#{attribute}=") }
  end

  describe '#to_h' do
    it 'expect to contain all the topic attrs plus id, name, consumer and consumer_group_id' do
      expected = (
        %w[kafka deserializer manual_offset_management] + %i[id name consumer consumer_group_id]
      )
      expect(topic.to_h.keys).to eq(expected)
    end
  end
end
