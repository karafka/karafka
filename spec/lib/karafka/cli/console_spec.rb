# frozen_string_literal: true

RSpec.describe_current do
  subject(:console_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:cmd) do
      envs = [
        "IRBRC='#{Karafka.gem_root}/.console_irbrc'",
        'KARAFKA_CONSOLE=true'
      ]
      "#{envs.join(' ')} bundle exec irb -r #{Karafka.boot_file}"
    end

    before do
      allow(cli).to receive(:info)
      allow(console_cli).to receive(:exec)
    end

    it 'expect to execute irb with boot file required' do
      console_cli.call
      expect(cli).to have_received(:info)
      expect(console_cli).to have_received(:exec).with(cmd)
    end
  end
end
