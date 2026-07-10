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
  let(:registry) { Karafka::Pro::Instrumentation::ConsumerGroups::LagCompensation::Registry.instance }

  let(:statistics) do
    {
      "name" => client_name,
      "topics" => {
        "topic" => {
          "partitions" => {
            "0" => {
              "hi_offset" => 10,
              "ls_offset" => 10,
              "committed_offset" => 5,
              "stored_offset" => 5,
              "consumer_lag" => 5,
              "consumer_lag_stored" => 5
            }
          }
        }
      }
    }
  end

  after { registry.evict(client_name) }

  context "when there is no refreshed data" do
    it "acts as the standard decorator" do
      expect(decorated["topics"]["topic"]["partitions"]["0"]["consumer_lag"]).to eq(5)
    end
  end

  context "when there is refreshed data" do
    before do
      registry.update(
        client_name,
        { "topic" => { 0 => 95 } }
      )
    end

    it "applies the lag compensation prior to the standard decoration" do
      partition = decorated["topics"]["topic"]["partitions"]["0"]

      expect(partition["ls_offset"]).to eq(95)
      expect(partition["consumer_lag"]).to eq(90)
    end
  end
end
