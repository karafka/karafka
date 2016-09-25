RSpec.describe Karafka::Logger do
  specify { expect(described_class).to be < ::Logger }
  subject(:logger_class) { described_class }

  describe '#instance' do
    let(:target) { double }
    let(:logger) { described_class.new(STDOUT) }
    let(:log_file) { Karafka::App.root.join('log', "#{Karafka.env}.log") }
    # A Pathname, because this is what is returned by File.join
    let(:log_dir) { File.dirname(log_file) }

    it 'creates an instance that will log in the app root' do
      expect(logger_class)
        .to receive(:target)
        .and_return(target)

      expect(logger_class)
        .to receive(:new)
        .with(target)
        .and_return(logger)

      logger_class.instance
    end

    it 'makes sure the "log" dir exists' do
      expect(Dir)
        .to receive(:exist?)
        .with(log_dir)
        .and_return(false)
      expect(Dir)
        .to receive(:mkdir)
        .with(log_dir)
        .and_return(0) # Don't ask me why, but this is what Dir.mkdir returns normally
      logger_class.instance
    end
  end

  describe '#target' do
    let(:delegate_scope) { double }
    let(:file) { double }

    it 'delegates write and close to STDOUT and file' do
      expect(Karafka::Helpers::MultiDelegator).to receive(:delegate)
        .with(:write, :close)
        .and_return(delegate_scope)

      expect(delegate_scope).to receive(:to)
        .with(STDOUT, file)

      expect(logger_class).to receive(:file)
        .and_return(file)

      logger_class.send(:target)
    end
  end

  describe '#file' do
    let(:file) { double }
    let(:log_file) { Karafka::App.root.join('log', "#{Karafka.env}.log") }

    it 'opens a log_file in append mode' do
      expect(File)
        .to receive(:open)
        .with(log_file, 'a')
        .and_return(file)

      expect(logger_class.send(:file)).to eq file
    end
  end
end
