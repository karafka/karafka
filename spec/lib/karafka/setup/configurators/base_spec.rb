require 'spec_helper'

RSpec.describe Karafka::Setup::Configurators::Base do
  subject { described_class }

  it { expect(subject).to respond_to :descendants }

  describe 'instance methods' do
    let(:config) { double }
    subject { described_class.new(config) }

    describe '#config' do
      it { expect(subject.config).to eq config }
    end

    describe '#setup' do
      it { expect { subject.setup }.to raise_error(NotImplementedError) }
    end
  end
end
