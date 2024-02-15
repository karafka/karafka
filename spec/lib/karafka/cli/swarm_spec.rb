# frozen_string_literal: true

RSpec.describe_current do
  subject(:swarm_cli) { described_class.new }

  let(:server_cli) { Karafka::Cli::Server.new }
  let(:supervisor) { Karafka::Swarm::Supervisor.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    before do
      allow(server_cli.class).to receive(:new).and_return(server_cli)
      allow(server_cli).to receive(:register_inclusions)
      allow(server_cli).to receive(:register_exclusions)
      allow(supervisor.class).to receive(:new).and_return(supervisor)
      allow(supervisor).to receive(:run)
    end

    context 'when we run in foreground (not daemonized)' do
      it 'expected to register inclusions and exclusions' do
        swarm_cli.call
        expect(server_cli).to have_received(:register_inclusions)
        expect(server_cli).to have_received(:register_exclusions)
      end

      it 'expect to run supervisor' do
        swarm_cli.call
        expect(supervisor).to have_received(:run)
      end
    end

    context 'when forking is not supported' do
      before { allow(::Karafka::Swarm).to receive(:supported?).and_return(false) }

      it 'expect to raise not supported error' do
        expect { swarm_cli.call }.to raise_error(Karafka::Errors::UnsupportedOptionError)
      end
    end
  end

  describe '#print_marketing_info' do
    it { expect { swarm_cli.send(:print_marketing_info) }.not_to raise_error }

    context 'when in pro' do
      before { allow(Karafka).to receive(:pro?).and_return(true) }

      it { expect { swarm_cli.send(:print_marketing_info) }.not_to raise_error }
    end
  end

  describe '#names' do
    it { expect(swarm_cli.class.names.sort).to eq %w[swarm].sort }
  end
end
