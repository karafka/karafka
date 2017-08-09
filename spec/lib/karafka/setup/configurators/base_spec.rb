# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::Base do
  subject(:base_configurator) { described_class }

  it { expect(base_configurator).to respond_to :descendants }

  describe 'instance methods' do
    subject(:base_configurator) { described_class.new(config) }

    let(:config) { double }

    describe '#config' do
      it { expect(base_configurator.config).to eq config }
    end

    describe '#setup' do
      it { expect { base_configurator.setup }.to raise_error(NotImplementedError) }
    end
  end
end
