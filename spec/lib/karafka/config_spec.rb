require 'spec_helper'

RSpec.describe Karafka::Config do
  subject { described_class.new }

  described_class::SETTINGS.each do |attribute|
    describe "#{attribute}=" do
      let(:value) { rand }
      before { subject.public_send(:"#{attribute}=", value) }

      it 'assigns a given value' do
        expect(subject.public_send(attribute)).to eq value
      end
    end
  end

  describe '.setup' do
    subject { described_class }
    let(:instance) { described_class.new }
    let(:block) { -> {} }

    before do
      instance

      @config = described_class.instance_variable_get('@config')
      described_class.instance_variable_set('@config', nil)

      expect(subject)
        .to receive(:new)
        .and_return(instance)

      expect(block)
        .to receive(:call)
        .with(instance)

      expect(instance)
        .to receive(:freeze)
    end

    after do
      described_class.instance_variable_set('@config', @config)
    end

    it { subject.setup(&block) }
  end
end
