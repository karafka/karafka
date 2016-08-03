require 'spec_helper'

RSpec.describe Karafka::Cli::Consume do
  let(:cli) { Karafka::Cli.new }
  subject(:consume_cli) { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    it 'expect to print info and expect to run consumer once' do
      expect(consume_cli)
        .to receive(:puts)
        .with('Starting Karafka messages consuming process')

      expect(Karafka::Consumer)
        .to receive(:run)

      consume_cli.call
    end
  end
end
