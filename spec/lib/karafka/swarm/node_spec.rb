# frozen_string_literal: true

RSpec.describe Karafka::Swarm::Node, mode: :fork do
  subject(:node) { build(:swarm_node_with_reader_and_writer) }

  describe '#write' do
    it 'expect not to fail' do
    end
  end

  describe '#read and #write' do
    context 'when nothing to read' do
      it { expect(node.read).to eq(false) }
      it { expect(node.write('1')).to eq(true) }
    end

    context 'when something to read' do
      before do
        node.write('1')
        # Wait as its async
        sleep(0.1)
      end

      it { expect(node.read).to eq('1') }
    end

    context 'when pipe for writing is closed' do
      before { node.instance_variable_get('@writer').close }

      it { expect(node.write('1')).to eq(false) }
    end

    context 'when pipe for reading is closed' do
      before { node.instance_variable_get('@reader').close }

      it { expect(node.read).to eq(false) }
    end
  end

  describe '#alive?' do
    # Fake fork with parent pid reference
    before do
      allow(node).to receive(:fork).and_return(fork_pid)
      node.start
    end

    context 'when node is alive' do
      let(:fork_pid) { Process.pid }

      it { expect(node.alive?).to eq(true) }
    end

    context 'when node pidfd could not be used' do
      let(:fork_pid) do
        pid = fork {}
        sleep(0.5)
        pid
      end

      it { expect(node.alive?).to eq(false) }
    end
  end

  describe '#start and #cleanup' do
    context 'when we could not open given pidfd' do
      before { allow(node).to receive(:fork).and_return(0) }

      it { expect { node.start }.to raise_error(Karafka::Errors::PidfdOpenFailedError) }
    end

    context 'when we want to start node without stubs' do
      it 'expect to start it (it will fail as not configured)' do
        expect { node.start }.not_to raise_error
        sleep(0.5)
        expect(node.alive?).to eq(false)
      end

      it 'expect to be able to cleanup even if cleanup multiple times' do
        node.start
        sleep(0.5)
        expect { node.cleanup }.not_to raise_error
        expect { node.cleanup }.not_to raise_error
      end
    end

    context 'when evaluating the start flow' do
      before do
        allow(node).to receive(:fork).and_return(Process.pid).and_yield
        allow(Karafka::Server).to receive(:run)
      end

      it { expect { node.start }.not_to raise_error }
    end
  end
end
