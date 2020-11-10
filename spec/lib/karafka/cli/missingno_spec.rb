# frozen_string_literal: true

RSpec.describe Karafka::Cli::Missingno do
  subject(:missingno_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    it 'expect to print a message and exit with exit code 1' do
      expect(Karafka.logger).to receive(:error).with('No command provided')
      expect(missingno_cli).to receive(:exit).with(1)
      missingno_cli.call
    end
  end
end
