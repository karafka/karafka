require 'spec_helper'

RSpec.describe Karafka::Setup::Config do
  subject { described_class }

  describe '#setup' do
    before do
      expect(subject)
        .to receive(:setup_components)
    end

    it { expect { |block| subject.setup(&block) }.to yield_with_args }
  end

  describe '#setup_components' do
    it 'expect to take descendants of BaseConfigurator and run setup on each' do
      Karafka::Setup::Configurators::Base.descendants.each do |descendant_class|
        config = double

        expect(descendant_class)
          .to receive(:new)
          .with(subject.config)
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
