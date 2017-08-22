# frozen_string_literal: true

RSpec.describe Karafka::Cli::Worker do
  subject(:worker_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:config_file) { Karafka::App.root.join('config/sidekiq.yml') }
    let(:cmd) do
      config = "-C #{Karafka::App.root.join('config/sidekiq.yml')}"
      req = "-r #{Karafka.boot_file}"
      env = "-e #{Karafka.env}"

      "bundle exec sidekiq #{env} #{req} #{config} #{params.join(' ')}"
    end

    before do
      expect(worker_cli)
        .to receive(:puts)
        .with('Starting Karafka worker')

      expect(cli)
        .to receive(:info)

      expect(worker_cli)
        .to receive(:puts)
        .with(cmd)

      expect(worker_cli)
        .to receive(:exec)
        .with(cmd)
    end

    context 'when we dont add any additional Sidekiq parameters' do
      let(:params) { [] }

      it 'expect to print info and execute Sidekiq with default options' do
        worker_cli.call
      end
    end

    context 'when we add any additional Sidekiq parameters' do
      let(:params) { ["-q #{rand}", "-e #{rand}"] }

      it 'expect to print info and execute Sidekiq with extra options' do
        worker_cli.call(*params)
      end
    end
  end
end
