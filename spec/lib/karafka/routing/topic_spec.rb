# frozen_string_literal: true

RSpec.describe Karafka::Routing::Topic do
  subject(:topic) { described_class.new(name, consumer_group) }

  let(:consumer_group) { instance_double(Karafka::Routing::ConsumerGroup, id: group_id) }
  let(:name) { :test }
  let(:group_id) { rand.to_s }
  let(:consumer) { Class.new(Karafka::BaseConsumer) }

  before do
    topic.consumer = consumer
    topic.backend = :inline
  end

  describe '#build' do
    Karafka::AttributesMap.topic.each do |attr|
      context "for #{attr}" do
        let(:attr_value) { attr == :backend ? :inline : rand.to_s }

        it 'expect to invoke it and store' do
          # Some values are build from other, so we add at least once as they
          # might be used internally
          expect(topic).to receive(attr).and_return(attr_value).at_least(:once)
          topic.build
        end
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

  describe '#backend' do
    before { topic.backend = backend }

    context 'when backend is not set' do
      let(:default_inline) { rand }
      let(:backend) { nil }

      before do
        expect(Karafka::App.config).to receive(:backend)
          .and_return(default_inline)
      end

      it 'expect to use Karafka::App default' do
        expect(topic.backend).to eq default_inline
      end
    end

    context 'when backend per topic is set to inline' do
      let(:backend) { :inline }

      it { expect(topic.backend).to eq backend }
    end
  end

  describe '#responder' do
    let(:consumer) { double }

    before do
      topic.responder = responder
      topic.consumer = consumer
    end

    context 'when responder is not set' do
      let(:responder) { nil }
      let(:built_responder) { double }
      let(:builder) { double }

      it 'expect to build responder using builder' do
        expect(Karafka::Responders::Builder).to receive(:new).with(consumer).and_return(builder)
        expect(builder).to receive(:build).and_return(built_responder)
        expect(topic.responder).to eq built_responder
      end
    end

    context 'when responder is set' do
      let(:responder) { double }

      it { expect(topic.responder).to eq responder }
    end
  end

  describe '#parser=' do
    let(:parser) { double }

    it { expect { topic.parser = parser }.not_to raise_error }
  end

  describe '#parser' do
    before { topic.parser = parser }

    context 'when parser is not set' do
      let(:parser) { nil }

      it 'expect to use default one' do
        expect(topic.parser).to eq Karafka::Parsers::Json
      end
    end

    context 'when parser is set' do
      let(:parser) { double }

      it { expect(topic.parser).to eq parser }
    end
  end

  Karafka::AttributesMap.topic.each do |attribute|
    it { expect(topic).to respond_to(attribute) }
    it { expect(topic).to respond_to(:"#{attribute}=") }
  end

  describe '#to_h' do
    it 'expect to contain all the topic map attributes plus id and consumer' do
      expected = (Karafka::AttributesMap.topic + %i[id consumer]).sort
      expect(topic.to_h.keys.sort).to eq(expected)
    end
  end
end
