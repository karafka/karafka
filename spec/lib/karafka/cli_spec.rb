# frozen_string_literal: true

RSpec.describe_current do
  subject(:cli) { described_class }

  describe ".commands" do
    let(:available_commands) do
      [
        Karafka::Cli::Console,
        Karafka::Cli::Info,
        Karafka::Cli::Install,
        Karafka::Cli::Server,
        Karafka::Cli::Topics,
        Karafka::Cli::Help,
        Karafka::Cli::Swarm
      ].map(&:to_s).sort
    end

    it "expect to return all cli commands classes" do
      expect(cli.send(:commands).map(&:to_s).sort).to eq available_commands
    end
  end

  describe ".start" do
    it "expect to use help when no command provided" do
      expect { cli.start }.not_to raise_error
    end
  end
end
