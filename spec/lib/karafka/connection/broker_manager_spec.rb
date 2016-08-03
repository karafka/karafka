require 'spec_helper'

RSpec.describe Karafka::Connection::BrokerManager do
  let(:zk) { double }
  let(:brokers_path) { Karafka::App.config.zookeeper.brokers_path }

  subject(:broker_manager) { described_class.new }

  describe '#all' do
    let(:ids) { [rand, rand, rand] }
    let(:brokers) { [double, double, double] }

    before do
      expect(broker_manager)
        .to receive(:ids)
        .and_return(ids)

      ids.each_with_index do |id, index|
        found_data = double

        expect(broker_manager)
          .to receive(:find)
          .with(id)
          .and_return(found_data)

        expect(Karafka::Connection::Broker)
          .to receive(:new)
          .with(found_data)
          .and_return(brokers[index])
      end
    end

    it 'expect to build brokers out of fetched details data' do
      expect(broker_manager.all).to eq brokers
    end
  end

  describe '#find' do
    let(:id) { rand.to_s }
    let(:broker_data) { double }
    let(:chroot) { rand.to_s }

    before do
      expect(broker_manager)
        .to receive(:zk)
        .and_return(zk)
    end

    it 'expect to get a proper broker data' do
      expect(zk)
        .to receive(:get)
        .with("/#{brokers_path}/#{id}")
        .and_return([broker_data])

      expect(broker_manager.send(:find, id)).to eq broker_data
    end

    it 'expect to use chroot when set' do
      ::Karafka::App.config.zookeeper.chroot = chroot
      expect(zk)
        .to receive(:get)
        .with("/#{chroot}/#{brokers_path}/#{id}")
        .and_return([broker_data])

      expect(broker_manager.send(:find, id)).to eq broker_data
    end
  end

  describe '#ids' do
    let(:result) { double }

    before do
      ::Karafka::App.config.zookeeper.chroot = nil

      expect(broker_manager)
        .to receive(:zk)
        .and_return(zk)

      expect(zk)
        .to receive(:children)
        .with("/#{brokers_path}")
        .and_return(result)
    end

    it { expect(broker_manager.send(:ids)).to eq result }
  end

  describe '#ids regarding chroot' do
    let(:result) { double }
    let(:chroot) { rand.to_s }

    before do
      ::Karafka::App.config.zookeeper.chroot = chroot

      expect(broker_manager)
        .to receive(:zk)
        .and_return(zk)

      expect(zk)
        .to receive(:children)
        .with("/#{chroot}/#{brokers_path}")
        .and_return(result)
    end

    it { expect(broker_manager.send(:ids)).to eq result }
  end

  describe '#zk' do
    let(:zk_instance) { double }

    it 'expect to create ZK instance out of joined hosts' do
      expect(ZK)
        .to receive(:new)
        .with(::Karafka::App.config.zookeeper.hosts.join(','))
        .and_return(zk_instance)

      broker_manager.send(:zk)
      expect(broker_manager.send(:zk)).to eq zk_instance
    end
  end

  describe '#path' do
    before do
      ::Karafka::App.config.zookeeper.chroot = chroot
      ::Karafka::App.config.zookeeper.brokers_path = brokers_path
    end

    context 'when chroot and brokers_path are not defined' do
      let(:chroot) { nil }
      let(:brokers_path) { nil }

      it { expect(broker_manager.send(:path)).to eq '/' }
    end

    context 'when chroot is defined but brokers_path is not' do
      let(:chroot) { rand.to_s }

      it { expect(broker_manager.send(:path)).to eq "/#{chroot}" }
    end

    context 'when chroot is not defined but brokers_path is' do
      let(:chroot) { nil }
      let(:brokers_path) { rand.to_s }

      it { expect(broker_manager.send(:path)).to eq "/#{brokers_path}" }
    end

    context 'when chroot and brokers_path are defined' do
      let(:chroot) { rand.to_s }
      let(:brokers_path) { rand.to_s }

      context 'and chroot starts with /' do
        let(:chroot) { "/#{rand}" }

        it { expect(broker_manager.send(:path)).to eq "#{chroot}/#{brokers_path}" }
      end

      context 'and chroot ends with /' do
        let(:chroot) { "#{rand}/" }

        it { expect(broker_manager.send(:path)).to eq "/#{chroot}#{brokers_path}" }
      end

      context 'and brokers_path starts with /' do
        let(:brokers_path) { "/#{rand}" }

        it 'expect to ignore chroot since we will go from root path' do
          expect(broker_manager.send(:path)).to eq brokers_path
        end
      end
    end
  end
end
