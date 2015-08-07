require 'spec_helper'

RSpec.describe Karafka::Consumer do
  subject { described_class.new(brokers, zookeeper_hosts) }
  let(:brokers) { double }
  let(:zookeeper_hosts) { double }
  describe '#receive' do
    let(:group_name) { double }
    let(:topic_name) { double }
    let(:consumer_group) { double(topic: 'A topic') }
    let(:options) { { socket_timeout_ms: 50_000 } }
    let(:bulk) { double }
    let(:message) { double(value: 'value') }
    let(:router) { double }

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

    let!(:another_klass) do
      # fake class
      class AnotherClass < Karafka::BaseController
        self.topic = 'B topic'
        self.group = 'B group'
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
      expect(consumer_group).to receive(:fetch)
        .and_yield(double, bulk)
      expect(bulk).to receive(:empty?)
        .and_return(false)
      expect(bulk).to receive(:each)
        .and_yield(message)
      expect(Karafka::Router).to receive(:new)
        .with(dummy_klass.topic, message.value).and_return(router)
      expect(router).to receive(:forward)
      expect(consumer_group).to receive(:close)
      subject.send(:fetch)
    end

    it 'receive loop' do
      # Mocking loop method to run only once
      class Object
        def loop
          yield
        end
      end
      expect(Object).to receive(:loop).once
      expect(subject).to receive(:fetch)
      subject.receive
    end
  end

  describe '#validate' do
    it 'raises DuplicatedTopicError once there are controllers with same topic' do
      allow(AnotherClass).to receive(:topic) { 'A topic' }
      expect { subject.receive }
        .to raise_error(Karafka::Consumer::DuplicatedTopicError)
    end

    it 'raises DuplicatedGroupError once there are controllers with same group' do
      allow(AnotherClass).to receive(:group) { 'A group' }
      expect { subject.receive }
        .to raise_error(Karafka::Consumer::DuplicatedGroupError)
    end
  end
end
