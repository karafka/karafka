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
  subject(:expansion) do
    Class.new do
      include Karafka::Pro::Routing::Features::Multiplexing::SubscriptionGroupsBuilder
    end.new.expand(topics_array)
  end

  let(:topic1) { build(:routing_topic) }
  let(:topic2) { build(:routing_topic) }
  let(:topics_array) { [topic1, topic2] }

  describe '#expand' do
    context 'when multiplexing is off' do
      before { topic1.subscription_group_details[:multiplexing_max] = 1 }

      it { expect(expansion.size).to eq(1) }
    end

    context 'when multiplexing is on with 3 copies' do
      before { topic1.subscription_group_details[:multiplexing_max] = 3 }

      it { expect(expansion.size).to eq(3) }

      it 'expect to share the same name' do
        names = []

        expansion.each do |topics|
          names += topics.map(&:name)
        end

        expect(names.uniq.size).to eq(1)
      end
    end
  end
end
