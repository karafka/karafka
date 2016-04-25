require 'spec_helper'

RSpec.describe Karafka::Setup::Defaults do
  subject { described_class }

  describe '#monitor' do
    it { expect(subject.monitor).to be_an_instance_of ::Karafka::Monitor }
  end

  describe '#kafka_hosts' do
    let(:kafka_hosts) { nil }
    let(:broker_manager) { double }
    let(:brokers) { [Karafka::Connection::Broker.new({}.to_json)] }

    it 'expect to use broker manager to discover them' do
      expect(Karafka::Connection::BrokerManager)
        .to receive(:new)
        .and_return(broker_manager)

      expect(broker_manager)
        .to receive(:all)
        .and_return(brokers)

      expect(subject.kafka_hosts).to eq brokers.map(&:host)
    end
  end

  describe '#logger' do
    it { expect(subject.logger).to be_an_instance_of ::Karafka::Logger }
  end
end
