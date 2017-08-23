# frozen_string_literal: true

RSpec.describe Karafka::Loader do
  subject(:loader) { described_class }

  describe '#load' do
    let(:relative_path) { Karafka.gem_root }
    let(:lib_path) { '/lib' }
    let(:app_path) { '/app' }

    before do
      stub_const('Karafka::Loader::DIRS', %w[lib app])
      expect(loader).to receive(:load!)
        .with(File.join(Karafka.gem_root, 'lib'))
        .and_return(double)

      # This one does not exist so we expect to skip it
      expect(loader).not_to receive(:load!)
        .with(File.join(Karafka.gem_root, 'app'))
    end

    it 'load paths for all DIRS that exist' do
      loader.load(relative_path)
    end
  end

  describe '#load!' do
    let(:path) { rand.to_s }

    it 'expect to use require_all' do
      expect(loader).to receive(:require_all).with(path)
      loader.load!(path)
    end
  end
end
