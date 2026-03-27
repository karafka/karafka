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
  subject(:topics) { Karafka::Routing::Topics.new([]) }

  let(:topic) { build(:routing_topic) }

  describe "#find" do
    before { topics << topic }

    context "when topic with given name exists" do
      it { expect(topics.find(topic.name)).to eq(topic) }
    end

    context "when topic with given name does not exist and no patterns" do
      it "expect to raise an exception as this should never happen" do
        expect { topics.find("na") }.to raise_error(Karafka::Errors::TopicNotFoundError, "na")
      end
    end

    context "when patterns exist but none matches" do
      let(:pattern_topic) { build(:pattern_routing_topic) }

      before { topics << pattern_topic }

      it "expect to raise an error as this should not happen" do
        expect { topics.find("na") }.to raise_error(Karafka::Errors::TopicNotFoundError, "na")
      end
    end

    context "when patterns exist and matched" do
      let(:pattern_topic) { build(:pattern_routing_topic, regexp: /.*/) }

      before { topics << pattern_topic }

      it "expect to raise an error as this should not happen" do
        expect(topics.find("exists").patterns.discovered?).to be(true)
      end
    end
  end
end
