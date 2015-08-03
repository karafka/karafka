require 'spec_helper'

RSpec.describe Karafka::Loader do
  subject { described_class }

  it { should be_const_defined(:DIRS) }

  describe '#base_sorter' do
    subject { described_class.new.base_sorter(str1, str2) }

    context 'when str1 is higher that str2' do
      let(:str1) { '/this' }
      let(:str2) { '/that/2' }

      it { expect(subject).to eq(-1) }
    end

    context 'when str2 is higher that str1' do
      let(:str2) { '/this' }
      let(:str1) { '/that/2' }

      it { expect(subject).to eq(1) }
    end

    context 'when str1 is equal to str2' do
      let(:str1) { '/this' }
      let(:str2) { '/that' }

      it { expect(subject).to eq(0) }
    end
  end

  describe '#relative_load!' do
    subject { described_class.new }

    let(:relative_path) { '/app/decorators' }
    let(:app_root) { '/apps/data_api' }
    let(:result) { double }

    before do
      expect(::Karafka)
        .to receive(:root)
        .and_return(app_root)
      expect(subject)
        .to receive(:load!)
        .with(File.join(app_root, relative_path))
        .and_return(result)
    end

    it 'executes #load! with built full path' do
      subject.relative_load!(relative_path)
    end
  end
end
