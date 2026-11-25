# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:expirer) { described_class.new(500, topic, 0) }

  let(:topic) { build(:routing_topic) }
  let(:messages) { [build(:messages_message)] }
  let(:events) { [] }
  let(:listener) { ->(event) { events << event } }

  before { Karafka.monitor.subscribe("filtering.expired", &listener) }

  after { Karafka.monitor.unsubscribe(listener) }

  context "when all messages are fresh" do
    it "expect not to filter" do
      expect { expirer.apply!(messages) }.not_to(change { messages })
    end

    it "expect not to apply" do
      expirer.apply!(messages)
      expect(expirer.applied?).to be(false)
    end

    it "expect to always skip" do
      expirer.apply!(messages)
      expect(expirer.action).to eq(:skip)
    end

    it "expect not to instrument" do
      expirer.apply!(messages)
      expect(events).to be_empty
    end
  end

  context "when there is a message older than ttl" do
    let(:older) { build(:messages_message, timestamp: Time.now.utc - 2) }
    let(:newer) { build(:messages_message, timestamp: Time.now.utc) }

    let(:messages) { [older, newer] }

    it "expect to filter" do
      expirer.apply!(messages)
      expect(messages).to eq([newer])
    end

    it "expect to always skip" do
      expirer.apply!(messages)
      expect(expirer.action).to eq(:skip)
    end

    it "expect to apply" do
      expirer.apply!(messages)
      expect(expirer.applied?).to be(true)
    end
  end

  context "when several messages are older than ttl" do
    let(:messages) do
      [
        build(:messages_message, offset: 10, timestamp: Time.now.utc - 3),
        build(:messages_message, offset: 11, timestamp: Time.now.utc),
        build(:messages_message, offset: 12, timestamp: Time.now.utc - 2),
        build(:messages_message, offset: 13, timestamp: Time.now.utc)
      ]
    end

    before { expirer.apply!(messages) }

    it "expect to keep only fresh messages" do
      expect(messages.map(&:offset)).to eq([11, 13])
    end

    it "expect to instrument once with expired messages details" do
      expect(events.size).to eq(1)

      event = events.first

      expect(event[:caller]).to eq(expirer)
      expect(event[:topic]).to eq(topic.name)
      expect(event[:partition]).to eq(0)
      expect(event[:subscription_group]).to eq(topic.subscription_group)
      expect(event[:count]).to eq(2)
      expect(event[:first_offset]).to eq(10)
      expect(event[:last_offset]).to eq(12)
      expect(event[:ttl]).to eq(500)
    end

    it "expect to report only the last run when applied again" do
      expirer.apply!([build(:messages_message, offset: 14, timestamp: Time.now.utc - 2)])

      expect(events.size).to eq(2)
      expect(events.last[:count]).to eq(1)
      expect(events.last[:first_offset]).to eq(14)
      expect(events.last[:last_offset]).to eq(14)
    end

    it "expect not to instrument nor stay applied when next run has nothing to expire" do
      expirer.apply!([build(:messages_message)])

      expect(events.size).to eq(1)
      expect(expirer.applied?).to be(false)
    end
  end
end
