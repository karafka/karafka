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
  subject(:topic) do
    build(:routing_share_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe "#dead_letter_queue" do
    context "when not configured" do
      it { expect(topic.dead_letter_queue.active?).to be(false) }
      it { expect(topic.dead_letter_queue.max_retries).to eq(3) }
      it { expect(topic.dead_letter_queue.dispatch_method).to eq(:produce_async) }
    end

    context "when configured" do
      before do
        topic.dead_letter_queue(topic: "dlq", max_retries: 1, dispatch_method: :produce_sync)
      end

      it { expect(topic.dead_letter_queue.active?).to be(true) }
      it { expect(topic.dead_letter_queue.topic).to eq("dlq") }
      it { expect(topic.dead_letter_queue.max_retries).to eq(1) }
      it { expect(topic.dead_letter_queue.dispatch_method).to eq(:produce_sync) }
    end
  end

  describe "#dead_letter_queue?" do
    context "when topic is set" do
      before { topic.dead_letter_queue(topic: "dlq") }

      it { expect(topic.dead_letter_queue?).to be(true) }
    end

    context "when topic is not set" do
      it { expect(topic.dead_letter_queue?).to be(false) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:dead_letter_queue]).to eq(topic.dead_letter_queue.to_h) }
  end
end
