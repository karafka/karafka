require 'spec_helper'

RSpec.describe Karafka::Configurators::Celluloid do
  specify { expect(described_class).to be < Karafka::Configurators::Base }

  let(:config) { double }
  subject { described_class.new(config) }

  describe '#setup' do
    it 'expect to assign Karafka logger to Celluloid' do
      expect(Celluloid)
        .to receive(:logger=)
        .with(Karafka.logger)

      subject.setup
    end
  end
end
