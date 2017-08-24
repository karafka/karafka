# frozen_string_literal: true

RSpec.describe Karafka::Routing::Topic do
  subject(:topic) { described_class.new(name, consumer_group) }

  let(:consumer_group) { instance_double(Karafka::Routing::ConsumerGroup, id: group_id) }
  let(:name) { :test }
  let(:group_id) { rand.to_s }
  let(:controller) { Class.new(Karafka::BaseController) }

  before do
    topic.controller = controller
    topic.processing_backend = :inline
  end

  describe '#build' do
    Karafka::AttributesMap.topic.each do |attr|
      context "for #{attr}" do
        let(:attr_value) { rand.to_s }

        it 'expect to invoke it and store' do
          # Some values are build from other, so we add at least once as they
          # might be used internally
          expect(topic).to receive(attr).and_return(attr).at_least(:once)
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

  describe '#worker' do
    before do
      topic.worker = worker
      topic.controller = controller
    end

    context 'when processing_backend is inline' do
      let(:worker) { false }

      before do
        topic.processing_backend = :inline
      end

      it { expect(topic.worker).to eq nil }
    end

    context 'when processing_backend is sidekiq' do
      before do
        topic.processing_backend = :sidekiq
      end

      context 'when worker is not set' do
        let(:worker) { nil }
        let(:built_worker) { double }
        let(:builder) { double }

        it 'expect to build worker using builder' do
          expect(Karafka::Workers::Builder).to receive(:new).with(controller).and_return(builder)
          expect(builder).to receive(:build).and_return(built_worker)
          expect(topic.worker).to eq built_worker
        end
      end
    end

    context 'when worker is set' do
      let(:worker) { double }

      it { expect(topic.worker).to eq worker }
    end
  end

  describe '#processing_backend' do
    before { topic.processing_backend = processing_backend }

    context 'when processing_backend is not set' do
      let(:default_inline) { rand }
      let(:processing_backend) { nil }

      before do
        expect(Karafka::App.config).to receive(:processing_backend)
          .and_return(default_inline)
      end

      it 'expect to use Karafka::App default' do
        expect(topic.processing_backend).to eq default_inline
      end
    end

    context 'when processing_backend per topic is set to sidekiq' do
      let(:processing_backend) { :sidekiq }

      it { expect(topic.processing_backend).to eq processing_backend }
    end

    context 'when processing_backend per topic is set to inline' do
      let(:processing_backend) { :inline }

      it { expect(topic.processing_backend).to eq processing_backend }
    end
  end

  describe '#responder' do
    let(:controller) { double }

    before do
      topic.responder = responder
      topic.controller = controller
    end

    context 'when responder is not set' do
      let(:responder) { nil }
      let(:built_responder) { double }
      let(:builder) { double }

      it 'expect to build responder using builder' do
        expect(Karafka::Responders::Builder).to receive(:new).with(controller).and_return(builder)
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

  describe '#interchanger=' do
    let(:interchanger) { double }

    it { expect { topic.interchanger = interchanger }.not_to raise_error }
  end

  describe '#interchanger' do
    before { topic.interchanger = interchanger }

    context 'when interchanger is not set' do
      let(:interchanger) { nil }

      it 'expect to use default one' do
        expect(topic.interchanger).to eq Karafka::Params::Interchanger
      end
    end

    context 'when interchanger is set' do
      let(:interchanger) { double }

      it { expect(topic.interchanger).to eq interchanger }
    end
  end

  Karafka::AttributesMap.topic.each do |attribute|
    it { expect(topic).to respond_to(attribute) }
    it { expect(topic).to respond_to(:"#{attribute}=") }
  end

  describe '#to_h' do
    it 'expect to contain all the topic map attributes plus id and controller' do
      expected = (Karafka::AttributesMap.topic + %i[id controller]).sort
      expect(topic.to_h.keys.sort).to eq(expected)
    end
  end
end
