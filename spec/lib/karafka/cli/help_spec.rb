# frozen_string_literal: true

RSpec.describe_current do
  subject(:help_cli) { described_class.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:helps) do
      <<~HELP.split("\n").flat_map { |str| str.split('#') }.map(&:strip)
        Karafka commands:
          console    # Starts the Karafka console (short-cut alias: "c")
          help       # Describes available commands
          info       # Prints configuration details and other options of your application
          install    # Installs all required things for Karafka application in current directory
          server     # Starts the Karafka server (short-cut aliases: "s", "consumer")
          topics     # Allows for the topics management
      HELP
    end

    let(:tmp_stdout) { StringIO.new }

    it 'expect to print details of this Karafka app instance' do
      original_stdout = $stdout
      $stdout = tmp_stdout
      help_cli.call
      $stdout = original_stdout

      helps.each { |help| expect(tmp_stdout.string).to include(help) }
    end
  end

  describe '#names' do
    it { expect(help_cli.class.names).to eq %w[help] }
  end
end
