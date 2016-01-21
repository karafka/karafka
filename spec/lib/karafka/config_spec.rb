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

    before do
      instance

      @config = described_class.instance_variable_get('@config')
      described_class.instance_variable_set('@config', nil)

      expect(subject)
        .to receive(:new)
        .and_return(instance)

      expect(instance)
        .to receive(:setup_components)

      expect(instance)
        .to receive(:freeze)
    end

    after do
      described_class.instance_variable_set('@config', @config)
    end

    it { expect { |block| subject.setup(&block) }.to yield_with_args }
  end
end

RSpec.describe Karafka::Config do
  subject { described_class.new }

  describe '#setup_components' do
    it 'expect to take descendants of BaseConfigurator and run setuo on each' do
      Karafka::Configurators::Base.descendants.each do |descendant_class|
        config = double

        expect(descendant_class)
          .to receive(:new)
          .with(subject)
          .and_return(config)
          .at_least(:once)

        expect(config)
          .to receive(:setup)
          .at_least(:once)
      end

      subject.send :setup_components
    end
  end
end
