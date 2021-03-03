# frozen_string_literal: true

RSpec.describe_current do
  subject(:karafka) { described_class }

  describe '.env' do
    it { expect(karafka.env).to eq('test') }
  end

  describe '.env=' do
    let(:new_env) { rand.to_s }

    before { karafka.env = new_env }

    after { karafka.env = 'test' }

    it { expect(karafka.env).to eq(new_env) }
    it { expect(karafka.env).to be_a(Karafka::Env) }
  end

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

      before do
        allow(ENV).to receive(:[]).with('KARAFKA_ROOT_DIR').and_return(root_dir_env)
        allow(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return('/Gemfile')
      end

      it do
        expect(karafka.root.to_path).to eq '/'
        expect(ENV).to have_received(:[]).with('BUNDLE_GEMFILE')
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
