require 'spec_helper'

RSpec.describe Karafka::Cli::Server do
  let(:cli) { Karafka::Cli.new }
  subject(:server_cli) { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    it 'expect to print info and expect to run Karafka application' do
      expect(server_cli)
        .to receive(:puts)
        .with('Starting Karafka framework server')

      expect(cli)
        .to receive(:info)

      expect(Karafka::Server)
        .to receive(:run)

      server_cli.call
    end
  end
end
