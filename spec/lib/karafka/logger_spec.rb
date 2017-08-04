# frozen_string_literal: true

RSpec.describe Karafka::Logger do
  specify { expect(described_class).to be < ::Logger }
  subject(:logger) { described_class.instance }

  describe '#instance' do
    let(:target) { double }
    let(:logger) { described_class.instance }
    let(:log_file) { Karafka::App.root.join('log', "#{Karafka.env}.log") }
    # A Pathname, because this is what is returned by File.join
    let(:log_dir) { File.dirname(log_file) }

    it 'expect to be of a proper level' do
      expect(logger.level).to eq ::Logger::ERROR
    end
  end

  describe '#target' do
    let(:delegate_scope) { double }
    let(:file) { double }

    it 'delegates write and close to STDOUT and file' do
      expect(Karafka::Helpers::MultiDelegator).to receive(:delegate)
        .with(:write, :close)
        .and_return(delegate_scope)

      expect(delegate_scope).to receive(:to).with(STDOUT, logger.send(:file))

      logger.send(:target)
    end
  end

  describe '#file' do
    let(:log_file) { Karafka::App.root.join('log', "#{Karafka.env}.log") }

    it 'opens a log_file in append mode' do
      expect(logger.send(:file).path.to_s).to eq log_file.to_s
    end
  end
end
