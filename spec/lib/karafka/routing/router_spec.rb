RSpec.describe Karafka::Routing::Router do
  subject(:router) { described_class.new(topic) }

  let(:topic) { "topic#{rand(1000)}" }

  describe '#build' do
    let(:parser) { double }
    let(:worker) { double }
    let(:responder) { double }
    let(:controller) { double }
    let(:interchanger) { double }
    let(:inline) { [true, false].sample }
    let(:controller_instance) { double }

    let(:route) do
      Karafka::Routing::Route.new.tap do |route|
        route.controller = controller
        route.topic = topic
        route.parser = parser
        route.worker = worker
        route.responder = responder
        route.interchanger = interchanger
        route.inline = inline
      end
    end

    before do
      allow(router)
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

      expect(controller_instance)
        .to receive(:responder=)
        .with(responder)

      expect(controller_instance)
        .to receive(:inline=)
        .with(inline)
    end

    it 'expect to build controller with all proper options assigned' do
      expect(router.build).to eq controller_instance
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

      it { expect(router.send(:route)).to eq routes.first }
    end

    context 'when there is no route for a given topic' do
      let(:routes) { [] }

      before do
        expect(Karafka::App)
          .to receive(:routes)
          .and_return(routes)
      end

      it { expect { router.send(:route) }.to raise_error(Karafka::Errors::NonMatchingRouteError) }
    end
  end
end
