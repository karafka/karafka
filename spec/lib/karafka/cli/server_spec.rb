# frozen_string_literal: true

RSpec.describe Karafka::Cli::Server do
  subject(:server_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }
  let(:pid) { rand.to_s }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    context 'when we run in foreground (not daemonized)' do
      before do
        allow(cli).to receive(:info)
        allow(Karafka::Server).to receive(:run)
      end

      it 'expect to print info and expect to run Karafka application' do
        expect { server_cli.call }.to output("Starting Karafka server\n").to_stdout
      end

      it 'expect to validate!' do
        expect(server_cli).to receive(:validate!)
        server_cli.call
      end

      it 'expect not to daemonize anything' do
        expect(server_cli).not_to receive(:daemonize)
        server_cli.call
      end
    end

    context 'when run in background (demonized)' do
      before do
        cli.options = { daemon: true, pid: 'tmp/pid' }

        allow(cli).to receive(:info)

        allow(FileUtils)
          .to receive(:mkdir_p)
          .with(File.dirname(cli.options[:pid]))

        allow(Karafka::Server).to receive(:run)
      end

      it 'expect to print info, validate!, daemonize and clean' do
        expect(server_cli).to receive(:validate!)
        expect(server_cli).to receive(:daemonize)

        expect { server_cli.call }.to output("Starting Karafka server\n").to_stdout
      end
    end
  end

  describe '#validate!' do
    context 'when server cli options are not valid' do
      let(:expected_error) { Karafka::Errors::InvalidConfiguration }

      before { cli.options = { daemon: true, pid: nil } }

      it 'expect to raise proper exception' do
        expect { server_cli.send(:validate!) }.to raise_error(expected_error)
      end
    end

    context 'when server cli options are ok' do
      before { cli.options = { daemon: false } }

      it 'expect not to raise exception' do
        expect { server_cli.send(:validate!) }.not_to raise_error
      end
    end
  end

  describe '#daemonize' do
    before { cli.options = { pid: pid } }
    let(:file) { instance_double(File, write: true) }

    it 'expect to daemonize and creat pidfile' do
      expect(::Process).to receive(:daemon)
        .with(true)
      expect(File).to receive(:open)
        .with(pid, 'w').and_yield(file)

      server_cli.send(:daemonize)
    end
  end

  describe '#clean' do
    before { cli.options = { pid: pid } }

    it 'expect to try to remove pidfile' do
      expect(FileUtils)
        .to receive(:rm_f).with(pid)

      server_cli.send(:clean)
    end
  end
end
