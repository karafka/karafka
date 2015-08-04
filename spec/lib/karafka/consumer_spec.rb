require 'spec_helper'

RSpec.describe Karafka::Consumer do
  describe '#receive' do
    let(:group_name) { double }
    let(:brokers) { double }
    let(:zookeeper_hosts) { double }
    let(:topic_name) { double }
    let(:consumer_group) { double }
    let(:options) { { socket_timeout_ms: 50_000 } }
    let(:bulk) { double }
    let(:message) { double(value: 'value') }

    it 'creates router for all messages' do
      # expect(Karafka).to receive_message_chain(:config, :socket_timeout_ms)
      # .and_return(50_000)
      expect(Poseidon::ConsumerGroup).to receive(:new)
        .with(group_name, brokers, zookeeper_hosts, topic_name, options)
        .and_return(consumer_group)
      expect(consumer_group).to receive(:fetch_loop)
        .and_yield(double, bulk)
      expect(bulk).to receive(:each)
        .and_yield(message)
      expect(Karafka::Router).to receive(:new)
        .with(topic_name, message.value)
      described_class.new(group_name, brokers, zookeeper_hosts, topic_name).receive
    end
  end
end
