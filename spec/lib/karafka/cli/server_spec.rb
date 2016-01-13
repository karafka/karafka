require 'spec_helper'

RSpec.describe Karafka::Cli do
  subject { described_class.new }

  describe 'server' do
    it 'expect to print info and expect to run Karafka application' do
      expect(subject)
        .to receive(:puts)
        .with('Starting Karafka framework')

      expect(subject)
        .to receive(:info)

      expect(Karafka::App)
        .to receive(:run)

      subject.server
    end
  end
end
