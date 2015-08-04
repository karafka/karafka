require 'spec_helper'

RSpec.describe Karafka::Logger do
  subject { described_class.new(STDOUT) }

  describe '.new' do
    let(:arg) { double }
    let(:block) { double }
    let(:result) { double }

    it 'should set a log level by default' do
      expect(subject.level).to_not be_nil
      expect(subject.level).to eq(::Logger::ERROR.to_i)
    end

    it 'has ability to set log level' do
      allow(ENV).to receive(:[]).with('EVENT_DELEGATOR_LOG_LEVEL')
        .and_return(::Logger::INFO.to_i)
      expect(subject.level).to eq(::Logger::INFO.to_i)
    end

    it 'redefine severity log messages' do
      allow(Karafka).to receive(:logger)
        .and_return(Karafka::Logger.new(STDOUT))
      expect_any_instance_of(::Logger).to receive(:info).with(nil)
      Karafka.logger.info('test was run')
    end
  end

  describe '#format' do
    it 'formats the arguments inside logger' do
      expect(subject.send(:format, 1, %w(a b c))).to eq('1 | a | b | c')
    end
  end
end
