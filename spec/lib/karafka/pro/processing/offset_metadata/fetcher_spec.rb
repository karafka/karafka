# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
