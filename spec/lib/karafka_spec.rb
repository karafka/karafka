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

  describe '#monitor' do
    context 'when monitor is already set' do
      let(:monitor) { double }

      before do
        subject.instance_variable_set(:'@monitor', monitor)
      end

      it 'should use monitor that was defined' do
        expect(subject.monitor).to eq monitor
      end
    end

    context 'when monitor is not provided' do
      let(:monitor) { double }

      before do
        subject.instance_variable_set(:'@monitor', nil)
      end

      it 'should build a default monitor' do
        expect(Karafka::Monitor)
          .to receive(:instance)
          .and_return(monitor)

        expect(subject.monitor).to eq monitor
      end
    end
  end

  describe '#monitor' do
    context 'when monitor is already set' do
      let(:monitor) { double }

      before do
        subject.instance_variable_set(:'@monitor', monitor)
      end

      it 'should use monitor that was defined' do
        expect(subject.monitor).to eq monitor
      end
    end

    context 'when monitor is not provided' do
      let(:monitor) { double }

      before do
        subject.instance_variable_set(:'@monitor', nil)
      end

      it 'should build a default monitor' do
        expect(Karafka::Monitor)
          .to receive(:instance)
          .and_return(monitor)

        expect(subject.monitor).to eq monitor
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

  describe '.boot_file' do
    before { ENV['KARAFKA_BOOT_FILE'] = boot_file }

    context 'when KARAFKA_BOOT_FILE is not defined' do
      let(:boot_file) { nil }
      let(:default) { File.join(Karafka.root, 'app.rb') }

      it 'expect to use default one' do
        expect(subject.boot_file).to eq default
      end
    end

    context 'when KARAFKA_BOOT_FILE is defined' do
      let(:boot_file) { rand.to_s }

      it 'expect to use one from env' do
        expect(subject.boot_file).to eq boot_file
      end
    end
  end
end
