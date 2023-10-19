# frozen_string_literal: true

RSpec.describe_current do
  subject(:help_cli) { described_class.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:help) do
      <<~HELP
        Karafka commands:
          console    # Starts the Karafka console (short-cut alias: "c")
          help       # Describes available commands
          info       # Prints configuration details and other options of your application
          install    # Installs all required things for Karafka application in current directory
          server     # Starts the Karafka server (short-cut alias: "s")
          topics     # Allows for the topics management (create, delete, reset, repartition)
      HELP
    end

    it 'expect to print details of this Karafka app instance' do
      expect { help_cli.call }.to output(help).to_stdout
    end
  end
end
