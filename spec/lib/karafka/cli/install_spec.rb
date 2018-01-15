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

      described_class::INSTALL_FILES_MAP.each do |source, target|
        allow(File)
          .to receive(:exist?)
          .with(Karafka.root.join(target))
          .and_return(false)

        allow(FileUtils)
          .to receive(:cp_r)
          .with(
            Karafka.core_root.join("templates/#{source}"),
            Karafka.root.join(target)
          )
      end
    end

    it 'expect to create proper dirs and copy template files' do
      expect { install_cli.call }.not_to raise_error
    end
  end
end
