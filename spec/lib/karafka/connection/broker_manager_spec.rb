require 'spec_helper'

RSpec.describe Karafka::Connection::BrokerManager do
  let(:zk) { double }

  describe '#all' do
    let(:ids) { [rand, rand, rand] }
    let(:brokers) { [double, double, double] }

    it 'expect to build brokers out of fetched details data' do
      expect(subject)
        .to receive(:ids)
        .and_return(ids)

      ids.each_with_index do |id, index|
        found_data = double

        expect(subject)
          .to receive(:find)
          .with(id)
          .and_return(found_data)

        expect(Karafka::Connection::Broker)
          .to receive(:new)
          .with(found_data)
          .and_return(brokers[index])
      end

      expect(subject.all).to eq brokers
    end
  end

  describe '#find' do
    let(:id) { rand.to_s }
    let(:broker_data) { double }
    let(:namespace) { '/namespace' }

    before do
      expect(subject)
        .to receive(:zk)
        .and_return(zk)
    end

    it 'expect to get a proper broker data' do
      expect(zk)
        .to receive(:get)
        .with("#{described_class::BROKERS_PATH}/#{id}")
        .and_return([broker_data])

      expect(subject.send(:find, id)).to eq broker_data
    end

    it 'expect to use namespace when set' do
      ::Karafka::App.config.zookeeper.namespace = namespace
      expect(zk)
        .to receive(:get)
        .with("#{namespace}#{described_class::BROKERS_PATH}/#{id}")
        .and_return([broker_data])

      expect(subject.send(:find, id)).to eq broker_data
    end
  end

  describe '#ids' do
    let(:result) { double }

    before do
      ::Karafka::App.config.zookeeper.namespace = nil

      expect(subject)
        .to receive(:zk)
        .and_return(zk)

      expect(zk)
        .to receive(:children)
        .with(described_class::BROKERS_PATH)
        .and_return(result)
    end

    it { expect(subject.send(:ids)).to eq result }
  end

  describe '#ids regarding namespace' do
    let(:result) { double }
    let(:namespace) { '/namespace' }

    before do
      ::Karafka::App.config.zookeeper.namespace = namespace

      expect(subject)
        .to receive(:zk)
        .and_return(zk)

      expect(zk)
        .to receive(:children)
        .with("#{namespace}#{described_class::BROKERS_PATH}")
        .and_return(result)
    end

    it { expect(subject.send(:ids)).to eq result }
  end

  describe '#zk' do
    let(:zk_instance) { double }

    it 'expect to create ZK instance out of joined hosts' do
      expect(ZK)
        .to receive(:new)
        .with(::Karafka::App.config.zookeeper.hosts.join(','))
        .and_return(zk_instance)

      subject.send(:zk)
      expect(subject.send(:zk)).to eq zk_instance
    end
  end

  describe '#namespace' do
    it 'expect to be empty when it is nil' do
      ::Karafka::App.config.zookeeper.namespace = nil
      expect(subject.send(:namespace)).to eq ''
    end

    it 'expect to be empty when it is blank' do
      ::Karafka::App.config.zookeeper.namespace = ''
      expect(subject.send(:namespace)).to eq ''
    end

    it 'expect to get namespace from config' do
      ::Karafka::App.config.zookeeper.namespace = '/namespace'
      expect(subject.send(:namespace)).to eq ::Karafka::App.config.zookeeper.namespace
    end

    it 'expect to add leading /' do
      ::Karafka::App.config.zookeeper.namespace = 'namespace'
      expect(subject.send(:namespace)).to eq '/namespace'
    end

    it 'expect to strip trailing /' do
      ::Karafka::App.config.zookeeper.namespace = 'namespace/'
      expect(subject.send(:namespace)).to eq '/namespace'
    end
  end
end
