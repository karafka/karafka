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
  let(:data) { { "topic" => { 0 => { lo_offset: 0, hi_offset: 10, committed_offset: 5 } } } }

  after { registry.evict(client_name) }

  describe "#update and #fetch" do
    it "returns stored data when fresh" do
      registry.update(client_name, data)

      expect(registry.fetch(client_name, 1_000)).to eq(data)
    end

    it "returns nil when there is no data for a given client" do
      expect(registry.fetch(client_name, 1_000)).to be_nil
    end

    it "returns nil when data is expired" do
      registry.update(client_name, data)

      sleep(0.01)

      expect(registry.fetch(client_name, 1)).to be_nil
    end

    it "replaces previously stored data" do
      registry.update(client_name, data)

      newer = { "topic" => { 0 => { lo_offset: 0, hi_offset: 20, committed_offset: 15 } } }
      registry.update(client_name, newer)

      expect(registry.fetch(client_name, 1_000)).to eq(newer)
    end
  end

  describe "#evict" do
    it "removes all the data of a given client" do
      registry.update(client_name, data)
      registry.evict(client_name)

      expect(registry.fetch(client_name, 1_000)).to be_nil
    end

    it "does not raise when the client has no data" do
      expect { registry.evict(client_name) }.not_to raise_error
    end
  end
end
