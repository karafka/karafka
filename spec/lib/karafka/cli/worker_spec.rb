require 'spec_helper'

RSpec.describe Karafka::Cli do
  subject { described_class.new }

  describe '#worker' do
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

      expect(subject)
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
        subject.worker
      end
    end

    context 'when we add any additional Sidekiq parameters' do
      let(:params) { ["-q #{rand}", "-e #{rand}"] }

      it 'expect to print info and execute Sidekiq with extra options' do
        subject.worker(*params)
      end
    end
  end
end
