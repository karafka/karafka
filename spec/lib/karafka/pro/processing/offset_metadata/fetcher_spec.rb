# frozen_string_literal: true

RSpec.describe_current do
  subject(:fetcher) { described_class }

  let(:client) { instance_double(Karafka::Connection::Client) }
  let(:topic) { build(:routing_topic) }

  before do
    allow(client).to receive(:subscription_group).and_return(topic.subscription_group)
    fetcher.register(client)
  end

  describe '#find' do
    context 'when looking for a topic that is no longer ours and not cached' do
      before { allow(client).to receive(:assignment).and_return({}) }

      it { expect(fetcher.find(topic, 0)).to be(false) }
    end

    context 'when looking for a topic partition that is no longer ours and not cached' do
      before { allow(client).to receive(:assignment).and_return({ topic.name => [] }) }

      it { expect(fetcher.find(topic, 0)).to be(false) }
    end

    context 'when looking for a topic partition that is ours' do
      before do
        allow(client).to receive_messages(
          assignment: { topic.name => [Rdkafka::Consumer::Partition.new(0, 0)] },
          committed: { topic.name => [Rdkafka::Consumer::Partition.new(0, 0, 0, 'test')] }
        )
      end

      it { expect(fetcher.find(topic, 0)).to eq('test') }
    end

    context 'when we received data, cached and cleared' do
      before do
        allow(client)
          .to receive(:assignment)
          .and_return(
            { topic.name => [Rdkafka::Consumer::Partition.new(0, 0)] },
            { topic.name => [] }
          )

        allow(client)
          .to receive(:committed)
          .and_return(topic.name => [Rdkafka::Consumer::Partition.new(0, 0, 0, 'test')])
      end

      it do
        expect(fetcher.find(topic, 0)).to eq('test')
        fetcher.clear(topic.subscription_group)
        expect(fetcher.find(topic, 0)).to be(false)
      end
    end
  end
end
