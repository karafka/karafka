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
  subject(:expirer) { described_class.new(500) }

  let(:messages) { [build(:messages_message)] }

  context 'when all messages are fresh' do
    it 'expect not to filter' do
      expect { expirer.apply!(messages) }.not_to(change { messages })
    end

    it 'expect not to apply' do
      expirer.apply!(messages)
      expect(expirer.applied?).to be(false)
    end

    it 'expect to always skip' do
      expirer.apply!(messages)
      expect(expirer.action).to eq(:skip)
    end
  end

  context 'when there is a message older than ttl' do
    let(:older) { build(:messages_message, timestamp: Time.now.utc - 2) }
    let(:newer) { build(:messages_message, timestamp: Time.now.utc) }

    let(:messages) { [older, newer] }

    it 'expect to filter' do
      expirer.apply!(messages)
      expect(messages).to eq([newer])
    end

    it 'expect to always skip' do
      expirer.apply!(messages)
      expect(expirer.action).to eq(:skip)
    end

    it 'expect to apply' do
      expirer.apply!(messages)
      expect(expirer.applied?).to be(true)
    end
  end
end
