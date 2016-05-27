require 'spec_helper'

RSpec.describe Karafka do
  subject { described_class }

  describe '.logger' do
    it 'expect to use app logger' do
      expect(subject.logger).to eq described_class::App.config.logger
    end
  end

  describe '.monitor' do
    it 'expect to use app monitor' do
      expect(subject.monitor).to eq described_class::App.config.monitor
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
      let(:default) { File.join(described_class.root, 'app.rb') }

      it 'expect to use default one' do
        expect(subject.boot_file).to eq Pathname.new(default)
      end
    end

    context 'when KARAFKA_BOOT_FILE is defined' do
      let(:boot_file) { rand.to_s }

      it 'expect to use one from env' do
        expect(subject.boot_file).to eq Pathname.new(boot_file)
      end
    end
  end
end
