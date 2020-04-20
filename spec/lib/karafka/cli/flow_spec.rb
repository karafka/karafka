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
            consumer Class.new(Karafka::BaseConsumer)
            backend :inline
          end
        end
      end

      let(:consumer_groups) { [consumer_group] }
      let(:responder) do
        declared_topics = topics
        Class.new(Karafka::BaseResponder) do
          declared_topics.each(&method(:topic))
        end
      end
      let(:topic) { "topic#{rand(1000)}" }

      before do
        allow(Karafka::App).to receive(:consumer_groups).and_return(consumer_groups)
      end

      context 'when they are without outgoing topics' do
        let(:topics) { [] }

        it 'expect to print that the flow is terminated' do
          expect(Karafka.logger).to receive(:info).with("#{topic} => (nothing)")
          flow_cli.call
        end
      end

      context 'when they are with outgoing topics' do
        let(:topics) { { topic => Karafka::Responders::Topic.new(topic, {}) } }

        it 'expect to log flow details' do
          expect(Karafka.logger).to receive(:info).once
          expect(flow_cli).to receive(:format)
          expect { flow_cli.call }.not_to raise_error
        end
      end
    end
  end

  describe '#format' do
    subject(:formatted) { flow_cli.send(:format, 'label', 'value') }
    
    it 'expect to format nicely' do
      expect(formatted).to eq('  - label:                value')
    end
  end
end
