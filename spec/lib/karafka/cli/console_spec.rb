RSpec.describe Karafka::Cli::Console do
  let(:cli) { Karafka::Cli.new }
  subject(:console_cli) { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:cmd) { "KARAFKA_CONSOLE=true bundle exec irb -r #{Karafka.boot_file}" }

    it 'expect to execute irb with boot file required' do
      expect(cli)
        .to receive(:info)

      expect(console_cli)
        .to receive(:system)
        .with(cmd)

      console_cli.call
    end
  end
end
