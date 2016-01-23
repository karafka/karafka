require 'spec_helper'

RSpec.describe Karafka::Routing::Router do
  subject { described_class.new(topic) }

  let(:topic) { "topic#{rand(1000)}" }

  describe '#build' do
    let(:parser) { double }
    let(:worker) { double }
    let(:controller) { double }
    let(:interchanger) { double }
    let(:controller_instance) { double }

    let(:route) do
      Karafka::Routing::Route.new.tap do |route|
        route.controller = controller
        route.topic = topic
        route.parser = parser
        route.worker = worker
        route.interchanger = interchanger
      end
    end

    it 'expect to build controller with all proper options assigned' do
      allow(subject)
        .to receive(:route)
        .and_return(route)

      expect(controller)
        .to receive(:new)
        .and_return(controller_instance)

      expect(controller_instance)
        .to receive(:topic=)
        .with(topic)

      expect(controller_instance)
        .to receive(:interchanger=)
        .with(interchanger)

      expect(controller_instance)
        .to receive(:parser=)
        .with(parser)

      expect(controller_instance)
        .to receive(:worker=)
        .with(worker)

      expect(subject.build).to eq controller_instance
    end
  end

  describe '#route' do
    context 'when there is a route for a given topic' do
      let(:routes) do
        [
          Karafka::Routing::Route.new.tap do |route|
            route.topic = topic
          end
        ]
      end

      before do
        expect(Karafka::App)
          .to receive(:routes)
          .and_return(routes)
      end

      it { expect(subject.send(:route)).to eq routes.first }
    end

    context 'when there is no route for a given topic' do
      let(:routes) { [] }

      before do
        expect(Karafka::App)
          .to receive(:routes)
          .and_return(routes)
      end

      it { expect { subject.send(:route) }.to raise_error(Karafka::Errors::NonMatchingRouteError) }
    end
  end
end
