require 'spec_helper'

RSpec.describe Karafka do
  subject { described_class }

  before do
    @logger = subject.logger
  end

  after do
    subject.logger = @logger
  end

  describe '#logger=' do
    let(:logger) { double }

    it 'should assign logger' do
      subject.logger = logger
      expect(subject.instance_variable_get(:'@logger')).to eq logger
    end
  end

  describe '#logger' do
    context 'when logger is already set' do
      let(:logger) { double }

      before do
        subject.instance_variable_set(:'@logger', logger)
      end

      it 'should use logger that was defined' do
        expect(subject.logger).to eq logger
      end
    end

    context 'when logger is not provided' do
      let(:logger) { double }

      before do
        subject.instance_variable_set(:'@logger', nil)
      end

      it 'should build a default logger' do
        expect(Karafka::Logger)
          .to receive(:build)
          .and_return(logger)

        expect(subject.logger).to eq logger
      end
    end
  end

  describe '.gem_root' do
    context 'when we want to get gem root path' do
      let(:path) { Dir.pwd }
      it { expect(subject.gem_root.to_path).to eq path }
    end
  end

  describe '.root' do
    context 'when we want to get app root path' do
      before do
        expect(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return('/')
      end

      it { expect(subject.root.to_path).to eq '/' }
    end
  end

  describe '.core_root' do
    context 'when we want to get core root path' do
      let(:path) { Pathname.new(File.join(Dir.pwd, 'lib', 'karafka')) }

      it do
        expect(subject.core_root).to eq path
      end
    end
  end

  describe '.env' do
    it 'should return current env' do
      expect(subject.env).to eq ENV['KARAFKA_ENV']
    end
  end
end
