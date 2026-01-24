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
  subject(:builder) { Karafka::Routing::Builder.new }

  let(:topic) { builder.first.topics.first }

  describe '#multiplexing' do
    before do
      builder.draw do
        consumer_group(:a) do
          subscription_group(:test) do
            multiplexing(min: 2, max: 3)

            topic(:test) { active(false) }
          end
        end
      end
    end

    it { expect(topic.subscription_group_details[:multiplexing_min]).to eq(2) }
    it { expect(topic.subscription_group_details[:multiplexing_max]).to eq(3) }
    it { expect(topic.subscription_group_details[:name]).to eq('test') }
  end
end
