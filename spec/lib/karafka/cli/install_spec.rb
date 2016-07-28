require 'spec_helper'

RSpec.describe Karafka::Cli::Install do
  let(:cli) { Karafka::Cli.new }
  subject { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    before do
      described_class::INSTALL_DIRS.each do |dir|
        expect(FileUtils)
          .to receive(:mkdir_p)
          .with(Karafka.root.join(dir))
      end

      described_class::INSTALL_FILES_MAP.each do |source, target|
        expect(File)
          .to receive(:exist?)
          .with(Karafka.root.join(target))
          .and_return(false)

        expect(FileUtils)
          .to receive(:cp_r)
          .with(
            Karafka.core_root.join("templates/#{source}"),
            Karafka.root.join(target)
          )
      end
    end

    it 'expect to create proper dirs and copy template files' do
      subject.call
    end
  end
end
