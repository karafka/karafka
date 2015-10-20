require 'spec_helper'

RSpec.describe Karafka::Connection::QueueConsumer do
  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }
  let(:controller) do
    double(
      group: group,
      topic: topic
    )
  end
  let(:max_wait_ms) { described_class::MAX_WAIT_MS }
  let(:socket_timeout_ms) { described_class::SOCKET_TIMEOUT_MS }

  describe 'preconditions' do
    it 'should have socket timeout bigger then wait timeout' do
      expect(max_wait_ms < socket_timeout_ms).to be true
    end
  end

  describe '.new' do
    subject { described_class.new(controller) }

    it 'expect to build instance using controller details' do
      expect_any_instance_of(described_class)
        .to receive(:registered?)
        .and_return(true)

      # We stub this because it would try to connect to zk
      expect(::ZK)
        .to receive(:new)

      expect(subject.options[:max_wait_ms]).to eq max_wait_ms
      expect(subject.options[:socket_timeout_ms]).to eq socket_timeout_ms
      expect(subject.topic).to eq topic
      expect(subject.name).to eq group
    end
  end
end
