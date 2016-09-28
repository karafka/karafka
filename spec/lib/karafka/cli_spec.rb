RSpec.describe Karafka::Cli do
  subject(:cli) { described_class }

  describe '.prepare' do
    let(:command) { Karafka::Cli::Server }
    let(:commands) { [command] }

    it 'expect to use all Cli commands defined' do
      expect(command)
        .to receive(:bind_to)
        .with(cli)

      cli.prepare
    end
  end

  describe '.cli_commands' do
    let(:available_commands) do
      [
        Karafka::Cli::Console,
        Karafka::Cli::Flow,
        Karafka::Cli::Info,
        Karafka::Cli::Install,
        Karafka::Cli::Routes,
        Karafka::Cli::Server,
        Karafka::Cli::Worker
      ]
    end

    it 'expect to return all cli commands classes' do
      expect(cli.send(:cli_commands)).to eq available_commands
    end
  end
end
