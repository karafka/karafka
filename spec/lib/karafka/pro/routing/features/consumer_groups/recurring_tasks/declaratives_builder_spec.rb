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

  let(:topics_cfg) { Karafka::App.config.recurring_tasks.topics }
  let(:schedules) { builder.find_topic(topics_cfg.schedules.name) }
  let(:logs) { builder.find_topic(topics_cfg.logs.name) }

  describe "#recurring_tasks" do
    context "when not active" do
      before { builder.recurring_tasks(false) }

      it { expect(builder.topics).to be_empty }
    end

    context "when active" do
      before { builder.recurring_tasks(true) }

      it "declares the schedules topic with compaction and retention" do
        expect(schedules.to_h[:details]).to eq(
          "cleanup.policy": "compact,delete",
          "retention.ms": 86_400_000
        )
      end

      it "declares the logs topic with delete cleanup and retention" do
        expect(logs.to_h[:details]).to eq(
          "cleanup.policy": "delete",
          "retention.ms": 604_800_000
        )
      end

      it "does not hardcode infrastructure sizing, leaving declaratives defaults" do
        expect(schedules.replication_factor).to eq(1)
        expect(schedules.partitions).to eq(1)
      end
    end

    context "when a declaratives default replication factor is set" do
      before do
        builder.defaults { replication_factor 3 }
        builder.recurring_tasks(true)
      end

      it { expect(schedules.replication_factor).to eq(3) }
      it { expect(logs.replication_factor).to eq(3) }
    end

    context "when redefining a declared topic afterwards" do
      before do
        builder.recurring_tasks(true)
        builder.topic(topics_cfg.schedules.name) { partitions 6 }
      end

      it "merges the override onto the feature declaration" do
        expect(schedules.partitions).to eq(6)
        expect(schedules.to_h[:details][:"cleanup.policy"]).to eq("compact,delete")
      end
    end

    context "when a block is given" do
      before do
        builder.recurring_tasks(true) do |schedules_topic, _logs_topic|
          schedules_topic.replication_factor 5
        end
      end

      it { expect(schedules.replication_factor).to eq(5) }
    end
  end
end
