# frozen_string_literal: true

RSpec.describe Karafka::Cli::Console do
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

    it 'expect to execute irb with boot file required' do
      expect(cli).to receive(:info)
      expect(console_cli).to receive(:exec).with(cmd)

      console_cli.call
    end
  end
end
