require 'spec_helper'

RSpec.describe Karafka do
  subject { described_class }

  describe '.gem_root' do
    context 'when we want to get gem root path' do
      let(:path) { Dir.pwd }
      it { expect(subject.gem_root.to_path).to eq path }
    end
  end

  describe '.root' do
    context 'when we want to get app root path' do
      before do
        expect(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return('/')
      end

      it { expect(subject.root.to_path).to eq '/' }
    end
  end

  describe '.core_root' do
    context 'when we want to get core root path' do
      let(:path) { Pathname.new(File.join(Dir.pwd, 'lib', 'karafka')) }

      it do
        expect(subject.core_root).to eq path
      end
    end
  end
end
