require 'spec_helper'

RSpec.describe Karafka::Setup::Config do
  subject(:config_class) { described_class }

  describe '#setup' do
    before do
      expect(config_class)
        .to receive(:setup_components)
    end

    it { expect { |block| config_class.setup(&block) }.to yield_with_args }
  end

  describe '#setup_components' do
    before do
      Karafka::Setup::Configurators::Base.descendants.each do |descendant_class|
        config = double

        expect(descendant_class)
          .to receive(:new)
          .with(config_class.config)
          .and_return(config)
          .at_least(:once)

        expect(config)
          .to receive(:setup)
          .at_least(:once)
      end
    end

    it 'expect to take descendants of BaseConfigurator and run setup on each' do
      config_class.send :setup_components
    end
  end
end
