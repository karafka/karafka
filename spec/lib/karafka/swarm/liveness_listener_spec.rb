# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:node) { build(:swarm_node_with_writer) }
  let(:pipe) { IO.pipe.last }
  let(:orphaned) { [false] }

  before do
    Karafka::App.config.swarm.node = node
    allow(node).to receive(:orphaned?).and_return(*orphaned)
  end

  after { Karafka::App.config.swarm.node = false }

  context 'when statistics are emitted too often' do
    context 'when node becomes orphaned' do
      let(:orphaned) { [false, true] }

      before do
        listener.on_statistics_emitted(nil)
        allow(Kernel).to receive(:exit!)
      end

      it 'expect to do nothing as too often' do
        listener.on_statistics_emitted(nil)
        expect(Kernel).not_to have_received(:exit!)
      end
    end
  end

  context 'when statistics are emitted not too often' do
    before { allow(node).to receive(:write) }

    it 'expect to write ok status to the node' do
      listener.on_statistics_emitted(nil)
      expect(node).to have_received(:write).with('0')
    end

    context 'when node becomes orphaned' do
      let(:orphaned) { [true] }

      before { allow(Kernel).to receive(:exit!) }

      it 'expect to exit!' do
        listener.on_statistics_emitted(nil)
        expect(Kernel).to have_received(:exit!).with(3)
      end
    end
  end
end
