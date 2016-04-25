require 'spec_helper'

RSpec.describe Karafka::Setup::Configurators::Internals do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  let(:config) { double(logger: logger, monitor: monitor) }
  subject { described_class.new(config) }

  let(:logger) { nil }
  let(:monitor) { nil }

  before do
    Karafka.logger = nil
    Karafka.monitor = nil
  end

  describe '#setup' do
    context 'when App logger is set in config' do
      let(:logger) { double }

      it 'expect to assign App logger to Karafka logger' do
        subject.setup

        expect(Karafka.logger).to eq logger
      end
    end

    context 'when App logger is not set in config' do
      it 'expect not to assign App logger to Karafka logger' do
        subject.setup

        expect(Karafka.logger).not_to eq logger
      end
    end

    context 'when App monitor is set in config' do
      let(:monitor) { double }

      it 'expect to assign App monitor to Karafka monitor' do
        subject.setup

        expect(Karafka.monitor).to eq monitor
      end
    end

    context 'when App monitor is not set in config' do
      it 'expect not to assign App monitor to Karafka monitor' do
        subject.setup

        expect(Karafka.monitor).not_to eq monitor
      end
    end
  end
end
