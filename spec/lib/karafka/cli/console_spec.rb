# frozen_string_literal: true

RSpec.describe_current do
  subject(:console_cli) { described_class.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  let(:info) { Karafka::Cli::Info.new }

  before { allow(info.class).to receive(:new).and_return(info) }

  describe '#call' do
    context 'when running without rails' do
      let(:cmd) do
        envs = [
          'KARAFKA_CONSOLE=true',
          "IRBRC='#{Karafka.gem_root}/.console_irbrc'"
        ]
        "#{envs.join(' ')} bundle exec irb -r #{Karafka.boot_file}"
      end

      before do
        allow(info).to receive(:call)
        allow(console_cli).to receive(:exec)
      end

      it 'expect to execute irb with boot file required' do
        console_cli.call
        expect(info).to have_received(:call)
        expect(console_cli).to have_received(:exec).with(cmd)
      end
    end

    context 'when running with rails' do
      let(:cmd) do
        'KARAFKA_CONSOLE=true bundle exec rails console'
      end

      before do
        allow(::Karafka).to receive(:rails?).and_return(true)
        allow(info).to receive(:call)
        allow(console_cli).to receive(:exec)
      end

      it 'expect to execute rails console' do
        console_cli.call
        expect(info).to have_received(:call)
        expect(console_cli).to have_received(:exec).with(cmd)
      end
    end
  end

  describe '#names' do
    it { expect(console_cli.class.names).to eq %w[c console] }
  end
end
