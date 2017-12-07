# frozen_string_literal: true

RSpec.describe Karafka do
  subject(:karafka) { described_class }

  describe '.logger' do
    it 'expect to use app logger' do
      expect(karafka.logger).to eq described_class::App.config.logger
    end
  end

  describe '.monitor' do
    it 'expect to use app monitor' do
      expect(karafka.monitor).to eq described_class::App.config.monitor
    end
  end

  describe '.gem_root' do
    context 'when we want to get gem root path' do
      let(:path) { Dir.pwd }

      it { expect(karafka.gem_root.to_path).to eq path }
    end
  end

  describe '.root' do
    context 'when we want to get app root path' do
      let(:root_dir_env) { nil }

      before { allow(ENV).to receive(:[]).with('KARAFKA_ROOT_DIR').and_return(root_dir_env) }

      it do
        expect(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return('/Gemfile')
        expect(karafka.root.to_path).to eq '/'
      end

      context 'when KARAFKA_ROOT_DIR is specified' do
        let(:root_dir_env) { './karafka_dir' }

        it { expect(karafka.root.to_path).to eq './karafka_dir' }
      end
    end
  end

  describe '.core_root' do
    context 'when we want to get core root path' do
      let(:path) { Pathname.new(File.join(Dir.pwd, 'lib', 'karafka')) }

      it do
        expect(karafka.core_root).to eq path
      end
    end
  end

  describe '.boot_file' do
    before { ENV['KARAFKA_BOOT_FILE'] = boot_file }

    context 'when KARAFKA_BOOT_FILE is not defined' do
      let(:boot_file) { nil }
      let(:default) { File.join(described_class.root, 'karafka.rb') }

      it 'expect to use default one' do
        expect(karafka.boot_file).to eq Pathname.new(default)
      end
    end

    context 'when KARAFKA_BOOT_FILE is defined' do
      let(:boot_file) { rand.to_s }

      it 'expect to use one from env' do
        expect(karafka.boot_file).to eq Pathname.new(boot_file)
      end
    end
  end
end
