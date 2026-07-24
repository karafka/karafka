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
  subject(:registry) { described_class.instance }

  let(:client_name) { SecureRandom.hex(6) }
  let(:data) { { "topic" => { 0 => { hi_offset: 10, ls_offset: 9, committed_offset: 5 } } } }

  after { registry.evict(client_name) }

  describe "#update and #fetch" do
    it "returns stored data when fresh" do
      registry.update(client_name, data)

      expect(registry.fetch(client_name)).to eq(data)
    end

    it "returns nil when there is no data for a given client" do
      expect(registry.fetch(client_name)).to be_nil
    end

    it "overwrites the values of refreshed partitions" do
      registry.update(client_name, data)

      newer = { "topic" => { 0 => { hi_offset: 20, ls_offset: 19, committed_offset: 15 } } }
      registry.update(client_name, newer)

      expect(registry.fetch(client_name)).to eq(newer)
    end

    it "keeps previously stored partitions absent from the refresh" do
      registry.update(client_name, data)
      registry.update(
        client_name,
        { "topic" => { 1 => { hi_offset: 20, ls_offset: 19, committed_offset: 15 } } }
      )

      expect(registry.fetch(client_name)).to eq(
        "topic" => {
          0 => { hi_offset: 10, ls_offset: 9, committed_offset: 5 },
          1 => { hi_offset: 20, ls_offset: 19, committed_offset: 15 }
        }
      )
    end

    it "keeps previously stored topics absent from the refresh" do
      registry.update(client_name, data)
      registry.update(
        client_name,
        { "other" => { 0 => { hi_offset: 7, ls_offset: 7, committed_offset: 3 } } }
      )

      expect(registry.fetch(client_name)).to eq(
        "topic" => { 0 => { hi_offset: 10, ls_offset: 9, committed_offset: 5 } },
        "other" => { 0 => { hi_offset: 7, ls_offset: 7, committed_offset: 3 } }
      )
    end
  end

  describe "#evict" do
    it "removes all the data of a given client" do
      registry.update(client_name, data)
      registry.evict(client_name)

      expect(registry.fetch(client_name)).to be_nil
    end

    it "does not raise when the client has no data" do
      expect { registry.evict(client_name) }.not_to raise_error
    end
  end
end
