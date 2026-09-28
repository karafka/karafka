# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::Logger do
  subject(:logger) { described_class.new }

  specify { expect(described_class).to be < Logger }

  describe "#new" do
    let(:karafka_test_root) { Pathname(Dir::Tmpname.create("karafka") { |_| nil }) }
    let(:log_path) { karafka_test_root.join("log/#{Karafka.env}.log") }

    before { allow(Karafka::App).to receive(:root).and_return(karafka_test_root) }

    after { FileUtils.rm_rf(karafka_test_root) }

    it "does not create a log file before the first write" do
      Dir.mkdir(karafka_test_root, 0o700)

      described_class.new

      expect(log_path).not_to exist
    end

    it "expect to be of a proper level" do
      expect(logger.level).to eq Logger::ERROR
    end

    context "when the dir does not exist" do
      context "when parent dir is not writable" do
        before { Dir.mkdir(karafka_test_root, 0o500) }

        specify do
          logger.error("message")

          expect(log_path).not_to exist
        end
      end

      context "when parent dir is writable" do
        before { Dir.mkdir(karafka_test_root, 0o700) }

        specify do
          logger.error("message")
          logger.send(:file).flush

          expect(log_path.read).to include("message")
        end
      end
    end

    context "when the dir exists and file does not exists" do
      before { Dir.mkdir(karafka_test_root, 0o700) }

      context "when dir is not writable" do
        before { Dir.mkdir(File.dirname(log_path), 0o500) }

        specify do
          logger.error("message")

          expect(log_path).not_to exist
        end
      end

      context "when dir is writable" do
        before { Dir.mkdir(File.dirname(log_path), 0o700) }

        specify do
          logger.error("message")
          logger.send(:file).flush

          expect(log_path.read).to include("message")
        end
      end
    end

    context "when file exists" do
      before { FileUtils.mkdir_p(File.dirname(log_path), mode: 0o700) }

      context "when file is writable" do
        before { FileUtils.install(File::NULL, log_path, mode: 0o700) }

        specify do
          logger.error("message")
          logger.send(:file).flush

          expect(log_path.read).to include("message")
        end
      end

      context "when file is not writable" do
        before { FileUtils.install(File::NULL, log_path, mode: 0o400) }

        specify do
          expect { logger.error("message") }.not_to change(log_path, :size)
        end
      end
    end
  end

  describe "#file" do
    let(:log_file) { Karafka::App.root.join("log", "#{Karafka.env}.log") }

    it "opens a log_file in append mode" do
      expect(logger.send(:file).path.to_s).to eq log_file.to_s
    end
  end

  describe "read-only filesystem handling (EROFS)" do
    let(:karafka_test_root) { Pathname(Dir::Tmpname.create("karafka") { |_| nil }) }
    let(:log_path) { karafka_test_root.join("log/#{Karafka.env}.log") }

    before do
      allow(Karafka::App).to receive(:root).and_return(karafka_test_root)
      Dir.mkdir(karafka_test_root, 0o700)
    end

    after { FileUtils.rm_rf(karafka_test_root) }

    context "when opening the log file raises EROFS" do
      before do
        # The log directory "exists" but the filesystem is read-only, so opening fails
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:open).with(log_path, "a").and_raise(Errno::EROFS)
      end

      it "does not raise and does not create the log file" do
        expect { logger.error("message") }.not_to raise_error
        expect(log_path).not_to exist
      end

      it "attempts to open the file only once across many writes" do
        logger.error("a")
        logger.error("b")
        logger.error("c")

        expect(File).to have_received(:open).with(log_path, "a").once
      end
    end

    context "when the file turns read-only after being opened (write raises EROFS)" do
      let(:handle) { instance_double(File, write: nil, close: nil) }

      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:open).with(log_path, "a").and_return(handle)
        allow(handle).to receive(:write).and_raise(Errno::EROFS)
      end

      it "does not raise" do
        expect { logger.error("message") }.not_to raise_error
      end
    end
  end
end
