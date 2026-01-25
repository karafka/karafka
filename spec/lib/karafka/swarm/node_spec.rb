# frozen_string_literal: true

RSpec.describe Karafka::Swarm::Node, mode: :fork do
  subject(:node) { build(:swarm_node_with_reader_and_writer) }

  describe "#status and #healthy" do
    context "when nothing to read" do
      it { expect(node.status).to eq(-1) }
      it { expect(node.healthy).to be(true) }
    end

    context "when healthy reported" do
      before do
        node.healthy
        # Wait as its async
        sleep(0.1)
      end

      it { expect(node.status).to eq(0) }
    end

    context "when unhealthy reported" do
      before do
        node.unhealthy
        # Wait as its async
        sleep(0.1)
      end

      it { expect(node.status).to eq(1) }
    end

    context "when pipe for writing is closed" do
      before { node.instance_variable_get(:@writer).close }

      it { expect(node.healthy).to be(false) }
    end

    context "when pipe for reading is closed" do
      before { node.instance_variable_get(:@reader).close }

      it { expect(node.status).to eq(-1) }
    end
  end

  describe "#orphaned?" do
    subject(:node) { described_class.new(0, Process.ppid) }

    it { expect(node.orphaned?).to be(false) }
  end

  describe "#stop" do
    before { allow(node).to receive(:signal) }

    it "expect to TERM for stop" do
      node.stop
      expect(node).to have_received(:signal).with("TERM")
    end
  end

  describe "#terminate" do
    before { allow(node).to receive(:signal) }

    it "expect to KILL for terminate" do
      node.terminate
      expect(node).to have_received(:signal).with("KILL")
    end
  end

  describe "#quiet" do
    before { allow(node).to receive(:signal) }

    it "expect to TSTP for quiet" do
      node.quiet
      expect(node).to have_received(:signal).with("TSTP")
    end
  end

  describe "#signal" do
    let(:signal_string) { "TERM" }

    before do
      node.instance_variable_set(:@pid, Process.pid)
      allow(Process).to receive(:kill)
    end

    it "expect to send signal using Process.kill" do
      expect(node.signal(signal_string)).to be(true)
      expect(Process).to have_received(:kill).with(signal_string, Process.pid)
    end

    context "when process does not exist" do
      before do
        allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
      end

      it "returns false" do
        expect(node.signal(signal_string)).to be(false)
      end
    end
  end

  describe "#alive?" do
    # Fake fork with parent pid reference
    before do
      allow(Process).to receive(:fork).and_return(fork_pid)
      node.start
    end

    context "when node is alive" do
      let(:fork_pid) { Process.pid }

      it { expect(node.alive?).to be(true) }
    end

    context "when node process is dead" do
      let(:fork_pid) do
        pid = fork { nil }
        sleep(0.5)
        pid
      end

      it { expect(node.alive?).to be(false) }
    end
  end

  describe "#start and #cleanup" do
    context "when we want to start node without stubs" do
      it "expect to start it" do
        expect { node.start }.not_to raise_error
        sleep(0.5)
        expect(node.alive?).to be(true)
      end

      it "expect to be able to cleanup even if cleanup multiple times" do
        node.start
        sleep(0.5)
        expect { node.cleanup }.not_to raise_error
        expect { node.cleanup }.not_to raise_error
      end
    end

    context "when evaluating the start flow" do
      before do
        allow(node).to receive(:fork).and_return(Process.pid).and_yield
        allow(Karafka::Server).to receive(:run)
      end

      it { expect { node.start }.not_to raise_error }
    end
  end
end
