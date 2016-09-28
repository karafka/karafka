RSpec.describe Karafka::Cli::Flow do
  let(:cli) { Karafka::Cli.new }
  subject(:flow_cli) { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    context 'when there are no routes' do
      let(:routes) { [] }

      it 'expect not to print anything' do
        expect(flow_cli).not_to receive(:print)
        flow_cli.call
      end
    end

    context 'when there are routes' do
      let(:route) do
        Karafka::Routing::Route.new.tap do |route|
          route.responder = responder
          route.topic = topic
        end
      end

      let(:karafka_routes) { [route] }
      let(:responder) { instance_double(Karafka::BaseResponder, topics: topics) }
      let(:topic) { "topic#{rand(1000)}" }

      before do
        expect(flow_cli)
          .to receive(:routes)
          .and_return(karafka_routes)
      end

      context 'without outgoing topics' do
        let(:topics) { nil }

        it 'expect to print that the flow is terminated' do
          expect(flow_cli).to receive(:puts).with("#{topic} => (nothing)")
          flow_cli.call
        end
      end

      context 'with outgoing topics' do
        let(:topics) { { topic => Karafka::Responders::Topic.new(topic, {}) } }

        it 'expect to print flow details' do
          allow(flow_cli).to receive(:puts)
          allow(flow_cli).to receive(:print)
          expect { flow_cli.call }.not_to raise_error
        end
      end
    end
  end

  describe '#routes' do
    let(:route1) { Karafka::Routing::Route.new.tap { |route| route.topic = :b } }
    let(:route2) { Karafka::Routing::Route.new.tap { |route| route.topic = :a } }
    let(:karafka_routes) { [route1, route2] }

    before do
      expect(Karafka::App)
        .to receive(:routes)
        .and_return(karafka_routes)
    end

    it { expect(flow_cli.send(:routes)).to eq [route2, route1] }
  end

  describe '#print' do
    let(:label) { rand.to_s }
    let(:value) { rand.to_s }

    it 'expect to printf nicely' do
      expect(flow_cli)
        .to receive(:printf)
        .with("%-25s %s\n", "  - #{label}:", value)

      flow_cli.send(:print, label, value)
    end
  end
end
