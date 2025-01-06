# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new }

  let(:cfg) { Karafka::App.config }
  let(:swarm_cfg) { cfg.internal.swarm }
  let(:original_node_report_timeout) { swarm_cfg.node_report_timeout }
  let(:original_node_restart_timeout) { swarm_cfg.node_restart_timeout }
  let(:original_shutdown_timeout) { cfg.shutdown_timeout }

  before do
    original_node_report_timeout
    original_node_restart_timeout
    original_shutdown_timeout

    allow(Process).to receive(:fork).and_return(Process.pid)
    manager.start
  end

  after do
    swarm_cfg.node_report_timeout = original_node_report_timeout
    swarm_cfg.node_restart_timeout = original_node_restart_timeout
    cfg.shutdown_timeout = original_shutdown_timeout
  end

  %i[
    quiet
    stop
    terminate
    cleanup
  ].each do |action|
    describe "##{action}" do
      before { manager.nodes.each { |node| allow(node).to receive(action) } }

      it "expect to #{action} each node" do
        manager.public_send(action)
        expect(manager.nodes).to all have_received(action)
      end
    end
  end

  describe '#signal' do
    let(:signal) { rand.to_s }

    before { manager.nodes.each { |node| allow(node).to receive(:signal) } }

    it 'expect to pass same to all nodes' do
      manager.signal(signal)
      expect(manager.nodes).to all have_received(:signal).with(signal)
    end
  end

  describe '#stopped?' do
    context 'when even one is alive' do
      it { expect(manager.stopped?).to be(false) }
    end

    context 'when none alive' do
      before { manager.nodes.each { |node| allow(node).to receive(:alive?).and_return(false) } }

      it { expect(manager.stopped?).to be(true) }
    end
  end

  describe '#control' do
    let(:target_node) { manager.nodes.first }

    context 'when node is alive and healthy' do
      before do
        manager.nodes.each do |node|
          allow(node).to receive(:stop)
          allow(node).to receive(:terminate)
        end
      end

      it 'expect not to trigger any actions on it' do
        manager.control

        manager.nodes.each do |node|
          expect(node).not_to have_received(:stop)
          expect(node).not_to have_received(:terminate)
        end
      end
    end

    context 'when node is alive but reported that is unhealthy' do
      before do
        allow(target_node).to receive(:status).and_return(1)

        manager.nodes.each do |node|
          allow(node).to receive(:stop)
          allow(node).to receive(:terminate)
        end
      end

      it 'expect to trigger stop on target node' do
        manager.control

        expect(target_node).to have_received(:stop)
      end

      it 'expect not to trigger terminate on any node' do
        manager.control

        manager.nodes.each do |node|
          expect(node).not_to have_received(:terminate)
        end
      end

      it 'expect not to trigger stop on other nodes' do
        manager.control

        manager.nodes.each do |node|
          next if node == target_node

          expect(node).not_to have_received(:stop)
        end
      end
    end

    context 'when node is not reporting any health for a short period of time' do
      before do
        allow(target_node).to receive(:status).and_return(-1)

        manager.nodes.each do |node|
          allow(node).to receive(:stop)
          allow(node).to receive(:terminate)
        end
      end

      it 'expect not to trigger stop or terminate on any nodes' do
        manager.control

        manager.nodes.each do |node|
          expect(node).not_to have_received(:stop)
          expect(node).not_to have_received(:terminate)
        end
      end
    end

    context 'when node is not reporting any health for a long period of time' do
      before do
        original_node_report_timeout
        swarm_cfg.node_report_timeout = 100

        manager.nodes.each do |node|
          allow(node).to receive(:stop)
          allow(node).to receive(:terminate)
          allow(node).to receive(:status).and_return(0)
        end

        allow(target_node).to receive(:status).and_return(-1)

        10.times do
          manager.control
          sleep(0.02)
        end

        manager.control
      end

      after { swarm_cfg.node_report_timeout = original_node_report_timeout }

      it 'expect to trigger stop on target node' do
        manager.control

        expect(target_node).to have_received(:stop)
      end

      it 'expect not to trigger terminate on any node' do
        manager.control

        manager.nodes.each do |node|
          expect(node).not_to have_received(:terminate)
        end
      end

      it 'expect not to trigger stop on other nodes' do
        manager.nodes.each do |node|
          next if node == target_node

          expect(node).not_to have_received(:stop)
        end
      end
    end

    context 'when node is alive but did not respond to stop request for a short time' do
      before do
        original_node_report_timeout
        swarm_cfg.node_report_timeout = 100

        manager.nodes.each do |node|
          allow(node).to receive(:stop)
          allow(node).to receive(:terminate)
          allow(node).to receive(:status).and_return(0)
        end

        allow(target_node).to receive(:status).and_return(-1)

        10.times do
          manager.control
          sleep(0.02)
        end

        manager.control
        sleep(0.02)
        manager.control
      end

      it 'expect to trigger stop on target node except the first one' do
        manager.control

        expect(target_node).to have_received(:stop).once
      end

      it 'expect not to trigger terminate on any node' do
        manager.control

        manager.nodes.each do |node|
          expect(node).not_to have_received(:terminate)
        end
      end

      it 'expect not to trigger stop on other nodes' do
        manager.nodes.each do |node|
          next if node == target_node

          expect(node).not_to have_received(:stop)
        end
      end
    end

    context 'when node is alive but did not respond to stop request for a long time' do
      before do
        swarm_cfg.node_report_timeout = 100
        cfg.shutdown_timeout = 50

        manager.nodes.each do |node|
          allow(node).to receive(:stop)
          allow(node).to receive(:terminate)
          allow(node).to receive(:status).and_return(0)
        end

        allow(target_node).to receive(:status).and_return(-1)

        10.times do
          manager.control
          sleep(0.02)
        end

        manager.control
        sleep(0.1)
        manager.control
      end

      it 'expect to trigger stop on target node except the first one' do
        manager.control

        expect(target_node).to have_received(:stop).once
        expect(target_node).to have_received(:terminate).once
      end

      it 'expect not to trigger terminate on other nodes' do
        manager.control

        manager.nodes.each do |node|
          next if node == target_node

          expect(node).not_to have_received(:terminate)
        end
      end

      it 'expect not to trigger stop on other nodes' do
        manager.nodes.each do |node|
          next if node == target_node

          expect(node).not_to have_received(:stop)
        end
      end
    end

    context 'when node has been stopped and it is still in a zombie mode' do
      before do
        manager.nodes.each do |node|
          allow(node).to receive(:start)
          allow(node).to receive(:stop)
          allow(node).to receive(:terminate)
          allow(node).to receive(:cleanup)
          allow(node).to receive(:status).and_return(0)
        end

        allow(target_node).to receive(:alive?).and_return(false)

        manager.control
        manager.control
      end

      it 'expect to collect state and not restart' do
        expect(target_node).to have_received(:cleanup).once
      end

      it 'expect not to start it yet' do
        expect(target_node).not_to have_received(:start)
      end

      it 'expect not to clean other nodes' do
        manager.nodes.each do |node|
          next if node == target_node

          expect(node).not_to have_received(:cleanup)
        end
      end
    end

    context 'when node has been stopped and it is time to restart it' do
      before do
        swarm_cfg.node_restart_timeout = 50

        manager.nodes.each do |node|
          allow(node).to receive(:start)
          allow(node).to receive(:stop)
          allow(node).to receive(:terminate)
          allow(node).to receive(:cleanup)
          allow(node).to receive(:status).and_return(0)
        end

        allow(target_node).to receive(:alive?).and_return(false)

        manager.control
        sleep(0.1)
        manager.control
      end

      it 'expect to collect state and not restart' do
        expect(target_node).to have_received(:cleanup).once
      end

      it 'expect to start it' do
        expect(target_node).to have_received(:start)
      end

      it 'expect not to clean or start other nodes' do
        manager.nodes.each do |node|
          next if node == target_node

          expect(node).not_to have_received(:cleanup)
          expect(node).not_to have_received(:start)
        end
      end
    end
  end
end
