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
  subject(:partitioner) { described_class.new(subscription_group) }

  # Virtual partitions settings have to be defined while drawing, as the routing validation reads
  # (and memoizes) them right after
  let(:vps) { nil }
  let(:subscription_group) do
    vps_settings = vps

    Karafka::Routing::Builder.new.draw do
      share_group :group_name do
        topic :topic_name do
          consumer Class.new(Karafka::ShareConsumer)
          virtual_partitions(**vps_settings) if vps_settings
        end
      end
    end.first.subscription_groups.first
  end

  let(:topic) { subscription_group.topics.first }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(topic, 0) }
  let(:messages) { Array.new(10) { build(:messages_message) } }
  let(:yielded) do
    yielded = []
    partitioner.call(topic.name, messages, coordinator) { |*args| yielded << args }
    yielded
  end

  it { expect(described_class).to be < Karafka::Processing::ShareGroups::Partitioner }

  context "when virtual partitions are not used" do
    it { expect(yielded).to eq([[0, messages]]) }
  end

  context "when using round robin" do
    let(:vps) { { partitioner: Karafka::Pro::Processing::ShareGroups::VirtualPartitions::Partitioners::RoundRobin.new, max_partitions: 3 } }

    it "expect to split the records across virtual partitions" do
      expect(yielded.map(&:first)).to match_array([0, 1, 2])
      expect(yielded.flat_map(&:last)).to match_array(messages)
    end
  end

  context "when max_partitions is 1" do
    let(:vps) { { partitioner: Karafka::Pro::Processing::ShareGroups::VirtualPartitions::Partitioners::RoundRobin.new, max_partitions: 1 } }

    it { expect(yielded).to eq([[0, messages]]) }
  end

  context "when the partitioner raises" do
    let(:errors) { [] }
    let(:vps) { { partitioner: ->(_) { raise StandardError }, max_partitions: 3 } }

    before do
      Karafka.monitor.subscribe("error.occurred") { |event| errors << event[:type] }
    end

    it "expect to fall back to a single group and report the error" do
      expect(yielded).to eq([[0, messages]])
      expect(errors).to include("virtual_partitions.partitioner.error")
    end
  end
end
