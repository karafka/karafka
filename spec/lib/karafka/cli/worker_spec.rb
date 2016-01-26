require 'spec_helper'

RSpec.describe Karafka::Cli::Worker do
  let(:cli) { Karafka::Cli.new }
  subject { described_class.new(cli) }

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
      expect(subject)
        .to receive(:puts)
        .with('Starting Karafka worker')

      expect(cli)
        .to receive(:info)

      expect(subject)
        .to receive(:puts)
        .with(cmd)

      expect(subject)
        .to receive(:exec)
        .with(cmd)
    end

    context 'when we dont add any additional Sidekiq parameters' do
      let(:params) { [] }

      it 'expect to print info and execute Sidekiq with default options' do
        subject.call
      end
    end

    context 'when we add any additional Sidekiq parameters' do
      let(:params) { ["-q #{rand}", "-e #{rand}"] }

      it 'expect to print info and execute Sidekiq with extra options' do
        subject.call(*params)
      end
    end
  end
end
