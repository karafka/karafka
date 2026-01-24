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
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      throttling: throttling
    }
  end

  let(:throttling) do
    {
      active: false,
      limit: 1,
      interval: 10
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active is not boolean' do
    before { throttling[:active] = 1 }

    it { expect(check).not_to be_success }
  end

  context 'when limit is less than 1' do
    before { throttling[:limit] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when interval is less than 1' do
    before { throttling[:interval] = 0 }

    it { expect(check).not_to be_success }
  end
end
