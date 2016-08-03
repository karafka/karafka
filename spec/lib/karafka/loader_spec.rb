require 'spec_helper'

RSpec.describe Karafka::Loader do
  subject(:loader_class) { described_class }

  it { should be_const_defined(:DIRS) }

  describe '#base_sorter' do
    subject(:loader) { described_class.new.send(:base_sorter, str1, str2) }

    context 'when str1 is higher that str2' do
      let(:str1) { '/this' }
      let(:str2) { '/that/2' }

      it { expect(loader).to eq(-1) }
    end

    context 'when str2 is higher that str1' do
      let(:str2) { '/this' }
      let(:str1) { '/that/2' }

      it { expect(loader).to eq(1) }
    end

    context 'when str1 is equal to str2' do
      let(:str1) { '/this' }
      let(:str2) { '/that' }

      it { expect(loader).to eq(0) }
    end
  end

  describe '#relative_load!' do
    subject(:loader) { described_class.new }

    let(:relative_path) { '/app/decorators' }
    let(:app_root) { '/apps/data_api' }
    let(:result) { double }

    before do
      expect(::Karafka)
        .to receive(:root)
        .and_return(app_root)
      expect(loader)
        .to receive(:load!)
        .with(File.join(app_root, relative_path))
        .and_return(result)
    end

    it 'executes #load! with built full path' do
      loader.relative_load!(relative_path)
    end
  end

  describe '#load' do
    subject(:loader) { described_class.new }
    let(:relative_path) { '/app/decorators' }
    let(:lib_path) { '/lib' }
    let(:app_path) { '/app' }

    before do
      stub_const('Karafka::Loader::DIRS', %w(lib app))
      expect(loader).to receive(:load!)
        .with('/app/decorators/lib')
        .and_return(double)
        .ordered
      expect(loader).to receive(:load!)
        .with('/app/decorators/app')
        .and_return(double)
        .ordered
    end

    it 'load paths for all DIRS' do
      loader.load(relative_path)
    end
  end
end
