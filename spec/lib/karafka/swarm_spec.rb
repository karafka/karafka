# frozen_string_literal: true

RSpec.describe_current do
  subject(:swarm) { described_class }

  context 'when supported' do
    before { allow(described_class).to receive(:supported?).and_return(true) }

    it 'expect not to raise that unsupported' do
      expect { swarm.ensure_supported! }.not_to raise_error
    end
  end

  context 'when not supported' do
    before { allow(::Process).to receive(:respond_to?).with(:fork).and_return(false) }

    it 'expect to raise that unsupported' do
      expect { swarm.ensure_supported! }.to raise_error(Karafka::Errors::UnsupportedOptionError)
    end
  end

  it { expect { swarm.supported? }.not_to raise_error }
end
