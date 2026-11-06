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
  subject(:admin) { described_class.new }

  it "expect to expose only reading methods" do
    expect(described_class.public_instance_methods(false)).to contain_exactly(
      :describe_cluster,
      :cluster_info,
      :read_watermark_offsets,
      :describe_topic_configs,
      :read_lags_with_offsets
    )
  end

  it "expect to describe the cluster" do
    expect(admin.describe_cluster[:brokers]).not_to be_empty
  end

  it "expect to read cluster metadata" do
    expect(admin.cluster_info.topics).to be_a(Array)
  end

  context "with an existing topic" do
    let(:topic_name) { generate_topic_name }

    before { Karafka::Admin.create_topic(topic_name, 1, 1) }

    it { expect(admin.read_watermark_offsets(topic_name => [0])).to eq(topic_name => { 0 => [0, 0] }) }
    it { expect(admin.describe_topic_configs(topic_name).map(&:name)).to include("retention.ms") }
  end

  it "expect to read lags without changing routing activity filters" do
    allow(Karafka::Admin).to receive(:read_lags_with_offsets).and_return({})

    admin.read_lags_with_offsets("cg" => ["t"])

    expect(Karafka::Admin)
      .to have_received(:read_lags_with_offsets)
      .with({ "cg" => ["t"] }, active_topics_only: false)
  end
end
