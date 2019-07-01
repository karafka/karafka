# frozen_string_literal: true

RSpec.describe Karafka::App do
  subject(:app_class) { described_class }

  describe '#consumer_groups' do
    let(:builder) { Karafka::App.config.internal.routing_builder }

    it 'returns consumer_groups builder' do
      expect(app_class.consumer_groups).to eq builder
    end
  end

  describe '#boot!' do
    let(:config) { double }

    before { allow(Karafka.monitor).to receive(:instrument) }

    it 'expect to run setup_components' do
      expect(Karafka::Setup::Config).to receive(:validate!).once
      expect(Karafka::Setup::Config).to receive(:setup_components).once

      app_class.boot!
    end

    it 'expect to publish app.initialized event' do
      expect(Karafka.monitor).to receive(:instrument).with('app.initialized')

      app_class.boot!
    end
  end

  describe '#reload' do
    let(:topic) { build(:routing_topic) }
    let(:consumers_persistence) { Karafka::Persistence::Consumers }
    let(:topics_persistence) { Karafka::Persistence::Topics }

    before do
      Karafka::App.config.internal.routing_builder.draw do
        topic :topic do
          consumer Class.new(Karafka::BaseConsumer)
        end
      end

      allow(Karafka::Routing::Router).to receive(:find).and_return(topic)
      consumers_persistence.fetch(topic, 0)
      topics_persistence.fetch(topic.consumer_group.id, topic.name)
    end

    context 'when we trigger reload' do
      it 'expect to invalidate the consumers cache' do
        expect { app_class.reload }.to change(Karafka::Persistence::Consumers, :current)
      end

      it 'expect to invalidate the topics cache' do
        expect { app_class.reload }.to change(Karafka::Persistence::Topics, :current)
      end

      it 'expect to redraw routes' do
        expect { app_class.reload }.to change(Karafka::App.config.internal, :routing_builder)
      end
    end
  end

  describe 'Karafka delegations' do
    %i[
      root
      env
    ].each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        it "expect to delegate #{delegation} method to Karafka module" do
          expect(Karafka)
            .to receive(delegation)
            .and_return(return_value)

          expect(app_class.public_send(delegation)).to eq return_value
        end
      end
    end
  end

  describe 'Karafka::Status delegations' do
    %i[
      run!
      running?
      stop!
    ].each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        it "expect to delegate #{delegation} method to Karafka module" do
          expect(Karafka::App.config.internal.status)
            .to receive(delegation)
            .and_return(return_value)

          expect(app_class.public_send(delegation)).to eq return_value
        end
      end
    end
  end
end
