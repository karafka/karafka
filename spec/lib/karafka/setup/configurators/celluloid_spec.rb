# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::Celluloid do
  subject(:celluloid_configurator) { described_class.new(config) }

  let(:config) do
    instance_double(
      Karafka::Setup::Config.config.class,
      client_id: ::Karafka::App.config.client_id,
      celluloid: OpenStruct.new(shutdown_timeout: shutdown_timeout)
    )
  end

  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  describe '#setup' do
    let(:shutdown_timeout) { rand(100) }

    it 'expect to assign Karafka logger to Celluloid and set a shutdown_timeout' do
      expect(Celluloid).to receive(:logger=).with(Karafka.logger)
      expect(Celluloid).to receive(:shutdown_timeout=).with(shutdown_timeout)

      celluloid_configurator.setup
    end
  end
end
