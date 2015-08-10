require 'spec_helper'

RSpec.describe Karafka::Consumer do
  subject { described_class.new }
  let(:kafka_hosts) { double }
  let(:zookeeper_hosts) { double }
  let(:consumer_group) { double(topic: :a_topic) }
  let(:bulk) { double }
  let(:message) { double(value: 'value') }
  let(:router) { double }
  let(:group_name) { double }
  let(:topic_name) { double }
  let!(:dummy_klass) do
    # fake class
    class DummyClass < Karafka::BaseController
      self.topic = :a_topic
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
        'B process'
      end
      self
    end
  end

  describe '#receive' do
    it 'receive loop' do
      # Mocking loop method to run only once
      class Object
        def loop
          yield
        end
      end
      expect(Karafka::BaseController).to receive(:descendants)
        .and_return([DummyClass, AnotherClass])
      expect(Object).to receive(:loop).once
      expect(subject).to receive(:fetch)
      subject.receive
    end
  end

  describe '#fetch' do
    before do
      allow(Karafka)
        .to receive_message_chain(:config, :kafka_hosts)
        .and_return(kafka_hosts)
      allow(Karafka)
        .to receive_message_chain(:config, :zookeeper_hosts)
        .and_return(zookeeper_hosts)
      allow(Karafka::BaseController)
        .to receive(:descendants) { [DummyClass] }
      expect(Poseidon::ConsumerGroup).to receive(:new)
        .with(dummy_klass.group, kafka_hosts, zookeeper_hosts, dummy_klass.topic.to_s)
        .and_return(consumer_group)
    end

    it 'creates router for all messages' do
      expect(consumer_group).to receive(:fetch)
        .and_yield(double, bulk)
      expect(bulk).to receive(:each)
        .and_yield(message)
      expect(Karafka::Router).to receive(:new)
        .with(dummy_klass.topic, message.value).and_return(router)
      expect(router).to receive(:forward)
      expect(consumer_group).to receive(:close)
      subject.send(:fetch)
    end

    it 'closes group once we have Poseidon::Connection::ConnectionFailedError ' do
      allow(consumer_group).to receive(:fetch)
        .and_raise(Poseidon::Connection::ConnectionFailedError)
      expect(consumer_group).to receive(:close)
      subject.send(:fetch)
    end
  end

  describe '#validate' do
    it 'raises DuplicatedTopicError once there are controllers with same topic' do
      allow(AnotherClass).to receive(:topic) { :a_topic }
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
