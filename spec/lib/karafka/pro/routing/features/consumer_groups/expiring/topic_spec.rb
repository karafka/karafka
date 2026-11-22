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
  subject(:topic) { build(:routing_topic) }

  describe "#expiring" do
    context "when we use expiring without any arguments" do
      it "expect to initialize with defaults" do
        expect(topic.expiring.active?).to be(false)
      end
    end

    context "when we use expiring with a ttl" do
      it "expect to use proper active status" do
        topic.expiring(1)
        expect(topic.expiring.active?).to be(true)
      end
    end

    context "when we use expiring multiple times with different values" do
      before do
        topic.expiring(1)
        topic.expire_in(2)
      end

      it "expect to use proper active status" do
        expect(topic.expiring.active?).to be(true)
      end

      it "expect not to add second expire" do
        expect(topic.filter.factories.size).to eq(1)
      end
    end

    context "when the filter is built for a partition" do
      subject(:expirer) { topic.filter.factories.first.call(topic, 3) }

      let(:events) { [] }
      let(:listener) { ->(event) { events << event } }
      let(:message) { build(:messages_message, timestamp: Time.now.utc - 2) }

      before do
        topic.expiring(1_000)
        Karafka.monitor.subscribe("filtering.expired", &listener)
        expirer.apply!([message])
      end

      after { Karafka.monitor.unsubscribe(listener) }

      it { expect(expirer).to be_a(Karafka::Pro::Processing::ConsumerGroups::Filters::Expirer) }

      it "expect to report expired messages for this topic partition" do
        expect(events.map { |event| [event[:topic], event[:partition]] }).to eq([[topic.name, 3]])
      end
    end
  end

  describe "#expiring?" do
    context "when active" do
      before { topic.expiring(1) }

      it { expect(topic.expiring?).to be(true) }
    end

    context "when not active" do
      before { topic.expiring }

      it { expect(topic.expiring?).to be(false) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:expiring]).to eq(topic.expiring.to_h) }
  end
end
