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
  subject(:decorated) { decorator.call(statistics) }

  let(:decorator) { described_class.new }
  let(:client_name) { SecureRandom.hex(6) }
  let(:registry) { Karafka::Pro::Instrumentation::PausedLags::Registry.instance }
  let(:interval) { 30_000 }

  let(:partition_stats) do
    {
      "lo_offset" => 0,
      "hi_offset" => 10,
      "committed_offset" => 5,
      "stored_offset" => 5,
      "consumer_lag" => 5,
      "consumer_lag_stored" => 5
    }
  end

  let(:statistics) do
    {
      "name" => client_name,
      "topics" => {
        "topic" => {
          "partitions" => { "0" => partition_stats }
        }
      }
    }
  end

  before { Karafka::App.config.internal.statistics.paused_refresh.interval = interval }

  after do
    Karafka::App.config.internal.statistics.paused_refresh.interval = 0
    registry.evict(client_name)
  end

  context "when there is no refreshed data for a given client" do
    it "does not change any of the values" do
      expect(decorated["topics"]["topic"]["partitions"]["0"]["consumer_lag"]).to eq(5)
      expect(decorated["topics"]["topic"]["partitions"]["0"]["hi_offset"]).to eq(10)
    end
  end

  context "when there is refreshed data" do
    before do
      registry.update(
        client_name,
        { "topic" => { 0 => { lo_offset: 1, hi_offset: 100, committed_offset: 40 } } }
      )
    end

    it "overlays watermarks, committed offset and derived lags" do
      partition = decorated["topics"]["topic"]["partitions"]["0"]

      expect(partition["lo_offset"]).to eq(1)
      expect(partition["hi_offset"]).to eq(100)
      expect(partition["committed_offset"]).to eq(40)
      expect(partition["consumer_lag"]).to eq(60)
      # Derived from the locally known stored offset and the refreshed high watermark
      expect(partition["consumer_lag_stored"]).to eq(95)
    end
  end

  context "when refreshed committed offset is -1" do
    before do
      registry.update(
        client_name,
        { "topic" => { 0 => { lo_offset: 1, hi_offset: 100, committed_offset: -1 } } }
      )
    end

    it "overlays watermarks but leaves committed offset and committed based lag untouched" do
      partition = decorated["topics"]["topic"]["partitions"]["0"]

      expect(partition["hi_offset"]).to eq(100)
      expect(partition["committed_offset"]).to eq(5)
      expect(partition["consumer_lag"]).to eq(5)
      expect(partition["consumer_lag_stored"]).to eq(95)
    end
  end

  context "when stored offset is -1" do
    before do
      partition_stats["stored_offset"] = -1

      registry.update(
        client_name,
        { "topic" => { 0 => { lo_offset: 1, hi_offset: 100, committed_offset: 40 } } }
      )
    end

    it "does not overlay the stored based lag" do
      expect(decorated["topics"]["topic"]["partitions"]["0"]["consumer_lag_stored"]).to eq(5)
    end
  end

  context "when refreshed data references a partition absent in statistics" do
    before do
      registry.update(
        client_name,
        { "topic" => { 5 => { lo_offset: 1, hi_offset: 100, committed_offset: 40 } } }
      )
    end

    it "does not raise nor change anything" do
      expect(decorated["topics"]["topic"]["partitions"]["0"]["consumer_lag"]).to eq(5)
    end
  end

  context "when the feature is disabled" do
    let(:interval) { 0 }

    before do
      registry.update(
        client_name,
        { "topic" => { 0 => { lo_offset: 1, hi_offset: 100, committed_offset: 40 } } }
      )
    end

    it "does not overlay anything even when data exists" do
      expect(decorated["topics"]["topic"]["partitions"]["0"]["consumer_lag"]).to eq(5)
    end
  end
end
