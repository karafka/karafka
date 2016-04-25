require 'spec_helper'

RSpec.describe Karafka::Setup::Configurators::Celluloid do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  let(:config) { double }
  subject { described_class.new(config) }

  describe '#setup' do
    it 'expect to assign Karafka logger to Celluloid and set a shutdown_timeout' do
      expect(Celluloid)
        .to receive(:logger=)
        .with(Karafka.logger)

      expect(Celluloid)
        .to receive(:shutdown_timeout=)
        .with(::Karafka::App.config.wait_timeout * 2)

      subject.setup
    end
  end
end
