# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::Celluloid do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  subject(:celluloid_configurator) { described_class.new(config) }

  let(:config) { double }

  describe '#setup' do
    let(:shutdown_timeout) { Karafka::Setup::Configurators::Celluloid::SHUTDOWN_TIME }

    it 'expect to assign Karafka logger to Celluloid and set a shutdown_timeout' do
      expect(Celluloid).to receive(:logger=).with(Karafka.logger)
      expect(Celluloid).to receive(:shutdown_timeout=).with(shutdown_timeout)

      celluloid_configurator.setup
    end
  end
end
