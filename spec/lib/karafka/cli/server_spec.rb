require 'spec_helper'

RSpec.describe Karafka::Cli::Server do
  let(:cli) { Karafka::Cli.new }
  subject { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    it 'expect to print info and expect to run Karafka application' do
      expect(subject)
        .to receive(:puts)
        .with('Starting Karafka framework')

      expect(cli)
        .to receive(:info)

      expect(Karafka::App)
        .to receive(:run)

      subject.call
    end
  end
end
