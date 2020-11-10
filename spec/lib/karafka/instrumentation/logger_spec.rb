# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::Logger do
  subject(:logger) { described_class.new }

  # We use a singleton logger that could be already initialized in other specs, so
  # in order to check all the behaviours we need to "reset" it to the initial state
  before { logger.instance_variable_set('@file', nil) }

  specify { expect(described_class).to be < ::Logger }

  describe '#new' do
    let(:target) { double }
    let(:log_file) { Karafka::App.root.join('log', "#{Karafka.env}.log") }
    # A Pathname, because this is what is returned by File.join
    let(:log_dir) { File.dirname(log_file) }
    let(:parent_dir) { File.dirname(log_dir) }

    it 'expect to be of a proper level' do
      expect(logger.level).to eq ::Logger::ERROR
    end

    context 'when the dir does not exist' do
      before do
        logger.instance_variable_set(:'@log_path', log_path)
        logger.send(:ensure_dir_exists)
      end

      context 'when it is not writable' do
        let(:log_path) { '/non-existing/test.log' }

        it { expect(File.exist?('/non-existing/')).to eq(false) }
      end

      context 'when it is writable' do
        let(:log_path) { '/tmp/non-existing/test.log' }

        it { expect(File.exist?(File.dirname(log_path))).to eq(true) }
      end
    end
  end

  describe '#target' do
    let(:delegate_scope) { double }

    it 'delegates write and close to $stdout and file' do
      expect(Karafka::Helpers::MultiDelegator).to receive(:delegate)
        .with(:write, :close)
        .and_return(delegate_scope)

      expect(delegate_scope).to receive(:to).with($stdout, logger.send(:file))

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
