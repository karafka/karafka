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
  subject(:validation) { described_class.new.call(config) }

  let(:config) do
    {
      virtual_partitions: {
        active: true,
        partitioner: :round_robin,
        reducer: ->(key) { key },
        max_partitions: 2,
        distribution: :consistent
      }
    }
  end

  context "when using round robin" do
    it { expect(validation).to be_success }
  end

  context "when using a callable partitioner" do
    before { config[:virtual_partitions][:partitioner] = ->(message) { message.key } }

    it { expect(validation).to be_success }
  end

  context "when active with an invalid partitioner" do
    before { config[:virtual_partitions][:partitioner] = :unknown }

    it { expect(validation).not_to be_success }
  end

  context "when not active" do
    before do
      config[:virtual_partitions][:active] = false
      config[:virtual_partitions][:partitioner] = nil
    end

    it { expect(validation).to be_success }
  end

  context "when max_partitions is below 1" do
    before { config[:virtual_partitions][:max_partitions] = 0 }

    it { expect(validation).not_to be_success }
  end

  context "when distribution is not supported" do
    before { config[:virtual_partitions][:distribution] = :unknown }

    it { expect(validation).not_to be_success }
  end
end
