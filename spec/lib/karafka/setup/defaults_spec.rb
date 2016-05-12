require 'spec_helper'

RSpec.describe Karafka::Setup::Defaults do
  subject { described_class }

  describe '#monitor' do
    it { expect(subject.monitor).to be_an_instance_of ::Karafka::Monitor }
  end

  describe '#kafka' do
    let(:broker_manager) { double }
    let(:brokers) { [Karafka::Connection::Broker.new({}.to_json)] }

    it 'expect to use broker manager to discover them' do
      expect(Karafka::Connection::BrokerManager)
        .to receive(:new)
        .and_return(broker_manager)

      expect(broker_manager)
        .to receive(:all)
        .and_return(brokers)

      expect(subject.kafka).to eq(hosts: brokers.map(&:host))
    end
  end

  describe '#logger' do
    it { expect(subject.logger).to be_an_instance_of ::Karafka::Logger }
  end
end
