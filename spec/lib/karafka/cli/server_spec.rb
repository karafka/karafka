# frozen_string_literal: true

RSpec.describe Karafka::Cli::Server do
  subject(:server_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }
  let(:pid) { rand.to_s }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  after { Celluloid.boot }

  describe '#call' do
    context 'when we run in foreground (not daemonized)' do
      before do
        expect(server_cli).to receive(:puts)
          .with('Starting Karafka server')

        expect(cli).to receive(:info)
        expect(Karafka::Server).to receive(:run)
      end

      it 'expect to print info and expect to run Karafka application' do
        server_cli.call
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

        expect(server_cli).to receive(:puts)
          .with('Starting Karafka server')

        expect(cli).to receive(:info)

        expect(FileUtils)
          .to receive(:mkdir_p)
          .with(File.dirname(cli.options[:pid]))

        expect(Karafka::Server).to receive(:run)
      end

      it 'expect to print info, validate!, daemonize and clean' do
        expect(server_cli).to receive(:validate!)
        expect(server_cli).to receive(:daemonize)

        server_cli.call
      end
    end
  end

  describe '#validate!' do
    context 'when server cli options are ok' do
      pending
    end

    context 'when server cli options are not valid' do
      pending
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
