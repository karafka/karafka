RSpec.describe Karafka::Routing::Router do
  subject(:router) { described_class.new(topic) }

  let(:topic) { "topic#{rand(1000)}" }

  describe '#build' do
    let(:parser) { double }
    let(:worker) { double }
    let(:responder) { double }
    let(:controller) { Karafka::BaseController }
    let(:interchanger) { double }
    let(:inline_mode) { [true, false].sample }
    let(:start_from_beginning) { [true, false].sample }
    let(:group) { rand.to_s }
    let(:batch_mode) { [true, false].sample }

    let(:route) do
      Karafka::Routing::Route.new.tap do |route|
        route.controller = controller
        route.topic = topic
        route.parser = parser
        route.worker = worker
        route.responder = responder
        route.interchanger = interchanger
        route.group = group
        route.batch_mode = batch_mode
        route.inline_mode = inline_mode
        route.start_from_beginning = start_from_beginning
      end
    end

    before do
      allow(router)
        .to receive(:route)
        .and_return(route)
    end

    it 'expect to build controller with all proper options assigned' do
      expect(router.build).to be_a(Karafka::BaseController)
    end

    it 'expect assign route into current instance' do
      expect(router.build.route).to eq route
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
