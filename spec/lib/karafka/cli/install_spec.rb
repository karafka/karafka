# frozen_string_literal: true

RSpec.describe Karafka::Cli::Install do
  subject(:install_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    before do
      described_class::INSTALL_DIRS.each do |dir|
        allow(FileUtils)
          .to receive(:mkdir_p)
          .with(Karafka.root.join(dir))
      end

      described_class::INSTALL_FILES_MAP.each do |_source, target|
        allow(Bundler)
          .to receive(:read_file)
          .and_return('')

        allow(File)
          .to receive(:open)
          .with(Karafka.root.join(target), 'w')
      end
    end

    it 'expect to create proper dirs and copy template files' do
      expect { install_cli.call }.not_to raise_error
    end
  end

  describe '#rails?' do
    subject(:is_rails) { described_class.new(cli).rails? }

    before { allow(Bundler).to receive(:read_file).and_return(gemfile) }

    context 'when railties is not in the gemfile' do
      let(:gemfile) { '' }

      it { expect(is_rails).to eq false }
    end

    context 'when railties is in the gemfile' do
      let(:gemfile) { "DEPENDENCIES\n  railties" }

      it { expect(is_rails).to eq true }
    end
  end
end
