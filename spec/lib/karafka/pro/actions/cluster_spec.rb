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
  subject(:action) { described_class.new(admin: admin) }

  let(:admin) { instance_double(Karafka::Pro::Actions::ReadOnlyAdmin) }
  let(:broker) { { id: 1, host: "127.0.0.1", port: 9092, rack: nil } }

  before do
    allow(admin).to receive(:describe_cluster).and_return(
      cluster_id: "abc", controller: broker, brokers: [broker], authorized_operations: nil
    )
  end

  it { expect(described_class.mode).to eq(:read) }
  it { expect(action.call).to eq(cluster_id: "abc", controller: broker, brokers: [broker]) }
end
