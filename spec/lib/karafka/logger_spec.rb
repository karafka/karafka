require 'spec_helper'

RSpec.describe Karafka::Logger do
  specify { expect(described_class).to be < ::Logger }
  subject { described_class }

  describe '#instance' do
    let(:target) { double }
    let(:log_file) { Karafka::App.root.join('log', "#{env}.log") }
    let(:logger) { described_class.new(STDOUT) }

    it 'creates an instance that will log in the app root' do
      expect(subject)
        .to receive(:target)
        .and_return(target)

      expect(subject)
        .to receive(:new)
        .with(target)
        .and_return(logger)

      subject.instance
    end
  end

  describe '#target' do
    let(:delegate_scope) { double }
    let(:file) { double }

    it 'delegates write and close to STDOUT and file' do
      expect(Karafka::Helpers::MultiDelegator)
        .to receive(:delegate)
        .with(:write, :close)
        .and_return(delegate_scope)

      expect(delegate_scope)
        .to receive(:to)
        .with(STDOUT, file)

      expect(subject)
        .to receive(:file)
        .and_return(file)

      subject.send(:target)
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

      expect(subject.send(:file)).to eq file
    end
  end
end
