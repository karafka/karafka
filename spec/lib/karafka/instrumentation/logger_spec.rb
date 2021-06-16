# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::Logger do
  subject(:logger) { described_class.new }

  let(:delegate_scope) { class_double(Karafka::Helpers::MultiDelegator) }

  # We use a singleton logger that could be already initialized in other specs, so
  # in order to check all the behaviours we need to "reset" it to the initial state
  before do
    allow(Karafka::Helpers::MultiDelegator).to receive(:delegate)
      .with(:write, :close)
      .and_return(delegate_scope)
    allow(delegate_scope).to receive(:to)
  end

  specify { expect(described_class).to be < ::Logger }

  describe '#new' do
    let(:karafka_test_root) { Pathname(Dir::Tmpname.create('karafka') { |_| }) }
    let(:log_path) { karafka_test_root.join("log/#{Karafka.env}.log") }
    let(:file_matcher) { having_attributes(closed?: false, path: log_path.to_path, class: File) }

    before { allow(Karafka::App).to receive(:root).and_return(karafka_test_root) }

    after { FileUtils.rm_rf(karafka_test_root) }

    it 'expect to be of a proper level' do
      expect(logger.level).to eq ::Logger::ERROR
    end

    context 'when the dir does not exist' do
      context 'when parent dir is not writable' do
        before { Dir.mkdir(karafka_test_root, 0o500) }

        specify do
          described_class.new
          expect(delegate_scope).to have_received(:to).with($stdout)
        end
      end

      context 'when parent dir is writable' do
        before { Dir.mkdir(karafka_test_root, 0o700) }

        specify do
          described_class.new
          expect(delegate_scope).to have_received(:to).with($stdout, file_matcher)
        end
      end
    end

    context 'when the dir exists and file does not exists' do
      before { Dir.mkdir(karafka_test_root, 0o700) }

      context 'when dir is not writable' do
        before { Dir.mkdir(File.dirname(log_path), 0o500) }

        specify do
          described_class.new
          expect(delegate_scope).to have_received(:to).with($stdout)
        end
      end

      context 'when dir is writable' do
        before { Dir.mkdir(File.dirname(log_path), 0o700) }

        specify do
          described_class.new
          expect(delegate_scope).to have_received(:to).with($stdout, file_matcher)
        end
      end
    end

    context 'when file exists' do
      before { FileUtils.mkdir_p(File.dirname(log_path), mode: 0o700) }

      context 'when file is writable' do
        before { FileUtils.install('/dev/null', log_path, mode: 0o700) }

        specify do
          described_class.new
          expect(delegate_scope).to have_received(:to).with($stdout, file_matcher)
        end
      end

      context 'when file is not writable' do
        before { FileUtils.install('/dev/null', log_path, mode: 0o400) }

        specify do
          described_class.new
          expect(delegate_scope).to have_received(:to).with($stdout)
        end
      end
    end
  end

  describe '#file' do
    let(:log_file) { Karafka::App.root.join('log', "#{Karafka.env}.log") }

    it 'opens a log_file in append mode' do
      expect(logger.send(:file).path.to_s).to eq log_file.to_s
    end
  end
end
