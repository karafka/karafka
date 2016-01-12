require 'spec_helper'

RSpec.describe Karafka::Cli do
  subject { described_class.new }

  describe '#worker' do
    let(:config_file) { Karafka::App.root.join('config/sidekiq.yml') }
    let(:cmd) { "bundle exec sidekiq -e #{Karafka.env} -r #{Karafka.boot_file} -C #{config_file}" }

    it 'expect to print info and execute Sidekiq with proper options' do
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

      subject.worker
    end
  end
end
