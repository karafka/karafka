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
  subject(:topic) { build(:routing_share_topic) }

  describe "#virtual_partitions" do
    context "when used without any arguments" do
      it "expect to initialize disabled with defaults" do
        expect(topic.virtual_partitions.active?).to be(false)
        expect(topic.virtual_partitions.partitioner).to be_nil
        expect(topic.virtual_partitions.max_partitions).to eq(Karafka::App.config.concurrency)
        expect(topic.virtual_partitions.distribution).to eq(:consistent)
      end
    end

    context "when using round robin" do
      before { topic.virtual_partitions(partitioner: :round_robin, max_partitions: 4) }

      it { expect(topic.virtual_partitions.active?).to be(true) }
      it { expect(topic.virtual_partitions.max_partitions).to eq(4) }
    end

    context "when using a custom partitioner" do
      before { topic.virtual_partitions(partitioner: ->(message) { message.key }) }

      it { expect(topic.virtual_partitions.active?).to be(true) }
      it { expect(topic.virtual_partitions.reducer.call("key")).to be_a(Integer) }
    end
  end

  describe "#virtual_partitions?" do
    it { expect(topic.virtual_partitions?).to be(false) }

    context "when enabled" do
      before { topic.virtual_partitions(partitioner: :round_robin) }

      it { expect(topic.virtual_partitions?).to be(true) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:virtual_partitions]).to eq(topic.virtual_partitions.to_h) }
  end
end
