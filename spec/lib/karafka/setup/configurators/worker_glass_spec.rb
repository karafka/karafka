RSpec.describe Karafka::Setup::Configurators::WorkerGlass do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  let(:config) { double }
  subject(:worker_glass_configurator) { described_class.new(config) }

  describe '#setup' do
    it 'expect to assign Karafka logger to WorkerGlass' do
      expect(WorkerGlass)
        .to receive(:logger=)
        .with(Karafka.logger)

      worker_glass_configurator.setup
    end
  end
end
