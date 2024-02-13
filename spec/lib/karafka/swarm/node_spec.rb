# frozen_string_literal: true

RSpec.describe Karafka::Swarm::Node, mode: :fork do
  subject(:node) { build(:swarm_node_with_reader_and_writer) }

  describe '#healthy? and #healthy' do
    context 'when nothing to read' do
      it { expect(node.healthy?).to eq(nil) }
      it { expect(node.healthy).to eq(true) }
    end

    context 'when healthy reported' do
      before do
        node.healthy
        # Wait as its async
        sleep(0.1)
      end

      it { expect(node.healthy?).to eq(true) }
    end

    context 'when unhealthy reported' do
      before do
        node.unhealthy
        # Wait as its async
        sleep(0.1)
      end

      it { expect(node.healthy?).to eq(false) }
    end

    context 'when pipe for writing is closed' do
      before { node.instance_variable_get('@writer').close }

      it { expect(node.healthy).to eq(false) }
    end

    context 'when pipe for reading is closed' do
      before { node.instance_variable_get('@reader').close }

      it { expect(node.healthy?).to eq(nil) }
    end
  end

  describe '#orphaned?' do
    it { expect(node.orphaned?).to eq(false) }
  end

  describe '#stop' do
    before { allow(node).to receive(:signal) }

    it 'expect to TERM for stop' do
      node.stop
      expect(node).to have_received(:signal).with('TERM')
    end
  end

  describe '#terminate' do
    before { allow(node).to receive(:signal) }

    it 'expect to KILL for terminate' do
      node.terminate
      expect(node).to have_received(:signal).with('KILL')
    end
  end

  describe '#quiet' do
    before { allow(node).to receive(:signal) }

    it 'expect to TSTP for quiet' do
      node.quiet
      expect(node).to have_received(:signal).with('TSTP')
    end
  end

  describe '#signal' do
    let(:signal_string) { rand.to_s }
    let(:pidfd) { node.instance_variable_get('@pidfd') }

    before { allow(pidfd).to receive(:signal) }

    it 'expect to pass through expected signal' do
      node.signal(signal_string)
      expect(pidfd).to have_received(:signal).with(signal_string)
    end
  end

  describe '#alive?' do
    # Fake fork with parent pid reference
    before do
      allow(Process).to receive(:fork).and_return(fork_pid)
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
      before { allow(Process).to receive(:fork).and_return(0) }

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
