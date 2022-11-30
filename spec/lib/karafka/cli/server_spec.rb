# frozen_string_literal: true

RSpec.describe_current do
  subject(:server_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }
  let(:pid) { rand.to_s }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    before { allow(Karafka::Server).to receive(:run) }

    context 'when we run in foreground (not daemonized)' do
      before { allow(cli).to receive(:info) }

      it 'expect not to daemonize anything' do
        expect(server_cli).not_to receive(:daemonize)
        server_cli.call
      end
    end
  end

  describe '#print_marketing_info' do
    it { expect { server_cli.send(:print_marketing_info) }.not_to raise_error }
  end
end
