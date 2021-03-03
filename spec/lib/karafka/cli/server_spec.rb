# frozen_string_literal: true

RSpec.describe_current do
  subject(:server_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }
  let(:pid) { rand.to_s }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    context 'when we run in foreground (not daemonized)' do
      before do
        allow(cli).to receive(:info)
        allow(Karafka::Server).to receive(:run)
      end

      it 'expect to validate!' do
        expect(server_cli).to receive(:validate!)
        server_cli.call
      end

      it 'expect not to daemonize anything' do
        expect(server_cli).not_to receive(:daemonize)
        server_cli.call
      end
    end
  end

  describe '#validate!' do
    context 'when server cli options are not valid' do
      let(:expected_error) { Karafka::Errors::InvalidConfigurationError }

      before { cli.options = { consumer_groups: [] } }

      it 'expect to raise proper exception' do
        expect { server_cli.send(:validate!) }.to raise_error(expected_error)
      end
    end

    context 'when server cli options are ok' do
      before { cli.options = {} }

      it 'expect not to raise exception' do
        expect { server_cli.send(:validate!) }.not_to raise_error
      end
    end
  end
end
