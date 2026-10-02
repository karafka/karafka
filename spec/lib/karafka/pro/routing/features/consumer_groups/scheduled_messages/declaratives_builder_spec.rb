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
  subject(:builder) do
    Karafka::Declaratives::Builder.new.tap do |builder|
      builder.singleton_class.prepend described_class
    end
  end

  let(:topic_name) { "messages" }
  let(:states_name) { "#{topic_name}#{Karafka::App.config.scheduled_messages.states_postfix}" }
  let(:messages) { builder.find_topic(topic_name) }
  let(:states) { builder.find_topic(states_name) }

  describe "#scheduled_messages" do
    context "when not active" do
      before { builder.scheduled_messages(false) }

      it { expect(builder.topics).to be_empty }
    end

    context "when active" do
      before { builder.scheduled_messages(topic_name) }

      it "declares the messages topic with tombstone compaction" do
        expect(messages.to_h[:details][:"cleanup.policy"]).to eq("compact")
      end

      it "declares the states topic with tombstone compaction" do
        expect(states.to_h[:details][:"cleanup.policy"]).to eq("compact")
      end

      it "keeps the messages and states partition counts matched" do
        expect(messages.partitions).to eq(5)
        expect(states.partitions).to eq(5)
      end

      it "does not hardcode the replication factor" do
        expect(messages.replication_factor).to eq(1)
        expect(states.replication_factor).to eq(1)
      end
    end

    context "when a declaratives default replication factor is set" do
      before do
        builder.defaults { replication_factor 3 }
        builder.scheduled_messages(topic_name)
      end

      it { expect(messages.replication_factor).to eq(3) }
      it { expect(states.replication_factor).to eq(3) }
    end
  end
end
