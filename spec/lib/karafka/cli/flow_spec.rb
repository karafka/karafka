# frozen_string_literal: true

RSpec.describe Karafka::Cli::Flow do
  subject(:flow_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    context 'when there are no consumer_groups' do
      let(:routes) { [] }

      it 'expect not to print anything' do
        expect(flow_cli).not_to receive(:print)
        flow_cli.call
      end
    end

    context 'when there are routes' do
      let(:consumer_group) do
        responder_instance = responder
        Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
          cg.public_send(:topic=, topic) do
            responder responder_instance
            controller Class.new
            processing_adapter :inline
          end
        end
      end

      let(:consumer_groups) { [consumer_group] }
      let(:responder) { instance_double(Karafka::BaseResponder, topics: topics) }
      let(:topic) { "topic#{rand(1000)}" }

      before do
        expect(Karafka::App)
          .to receive(:consumer_groups)
          .and_return(consumer_groups)
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
