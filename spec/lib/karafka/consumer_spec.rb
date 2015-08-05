require 'spec_helper'

RSpec.describe Karafka::Consumer do
  describe '#receive' do
    let(:group_name) { double }
    let(:brokers) { double }
    let(:zookeeper_hosts) { double }
    let(:topic_name) { double }
    let(:consumer_group) { double(topic: 'A topic') }
    let(:options) { { socket_timeout_ms: 50_000 } }
    let(:bulk) { double }
    let(:message) { double(value: 'value') }
    subject { described_class.new(brokers, zookeeper_hosts) }
    let!(:dummy_klass) do
      # fake class
      class DummyClass < Karafka::BaseController
        self.topic = 'A topic'
        self.group = 'A group'
        def process
          'A process'
        end
        self
      end
    end

    it 'creates router for all messages' do
      # expect(Karafka).to receive_message_chain(:config, :socket_timeout_ms)
      # .and_return(50_000)
      allow(Karafka::BaseController)
        .to receive(:descendants) { [DummyClass] }
      expect(Poseidon::ConsumerGroup).to receive(:new)
        .with(dummy_klass.group, brokers, zookeeper_hosts, dummy_klass.topic, options)
        .and_return(consumer_group)
      expect(consumer_group).to receive(:fetch_loop)
        .and_yield(double, bulk)
      expect(bulk).to receive(:empty?)
        .and_return(false)
      expect(bulk).to receive(:each)
        .and_yield(message)
      expect(Karafka::Router).to receive(:new)
        .with(dummy_klass.topic, message.value)
      described_class.new(brokers, zookeeper_hosts).send(:fetch)
    end

    it 'receive loop' do
      expect(subject).to receive(:fetch).exactly(3).times
      subject.receive
    end
  end
end

# Mock loop to 3 times; should be remockedg
class Object
  private

  def loop
    3.times do
      yield
    end
  end
end
