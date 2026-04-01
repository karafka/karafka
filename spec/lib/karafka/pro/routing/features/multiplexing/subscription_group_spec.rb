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
  subject(:sg) { build(:routing_subscription_group) }

  let(:max) { 2 }
  let(:min) { 1 }

  describe "#multiplexing and multiplexing?" do
    before do
      sg.topics.first.subscription_group_details.merge!(
        multiplexing_max: max,
        multiplexing_min: min
      )
    end

    it { expect(sg.multiplexing?).to be(true) }
    it { expect(sg.multiplexing.active?).to be(true) }
    it { expect(sg.multiplexing.dynamic?).to be(true) }

    context "when max is 1" do
      let(:max) { 1 }

      it { expect(sg.multiplexing?).to be(false) }
      it { expect(sg.multiplexing.active?).to be(false) }
      it { expect(sg.multiplexing.dynamic?).to be(false) }
    end

    context "when min and max are the same" do
      let(:min) { 3 }
      let(:max) { 3 }

      it { expect(sg.multiplexing?).to be(true) }
      it { expect(sg.multiplexing.active?).to be(true) }
      it { expect(sg.multiplexing.dynamic?).to be(false) }
    end
  end
end
