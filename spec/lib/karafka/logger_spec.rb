require 'spec_helper'

RSpec.describe Karafka::Logger do
  specify { expect(described_class).to be < ::Logger }

  describe '#build' do
    let(:env) { 'test' }
    let(:log_file) { Karafka::App.root.join('log', "#{env}.log") }
    let(:logger) { Karafka::Logger.new(STDOUT) }

    it 'should create an instance that will log in the app root' do
      expect(Karafka)
        .to receive(:env)
        .and_return(env)
        .exactly(2).times

      expect(described_class)
        .to receive(:new)
        .with(log_file)
        .and_return(logger)

      described_class.build
    end
  end
end
