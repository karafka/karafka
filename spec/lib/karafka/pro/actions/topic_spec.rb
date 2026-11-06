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
  let(:config_class) { Karafka::Admin::Configs::Config }
  let(:metadata) do
    Struct.new(:topics).new(
      [
        {
          topic_name: "orders",
          partition_count: 1,
          partitions: [{ partition_id: 0, leader: 1, replicas: [1], isrs: [1] }]
        }
      ]
    )
  end
  let(:configs) do
    [
      config_class.new(name: "retention.ms", value: "1000"),
      config_class.new(name: "sasl.password", value: "secret"),
      config_class.new(name: "other", value: "hidden", sensitive: 1)
    ]
  end

  before do
    allow(admin).to receive_messages(
      cluster_info: metadata,
      read_watermark_offsets: { "orders" => { 0 => [2, 10] } },
      describe_topic_configs: configs
    )
  end

  it "expect to return partitions with watermarks" do
    expect(action.call(topic_name: "orders")[:partitions]).to eq(
      [
        {
          partition: 0,
          leader: 1,
          replicas: [1],
          in_sync_replicas: [1],
          low_watermark: 2,
          high_watermark: 10
        }
      ]
    )
  end

  it "expect to redact sensitive configs" do
    values = action.call(topic_name: "orders")[:configs].to_h { |c| [c[:name], c[:value]] }

    expect(values).to eq(
      "retention.ms" => "1000",
      "sasl.password" => "[REDACTED]",
      "other" => "[REDACTED]"
    )
  end

  it "expect to raise not found for a missing topic without asking for its metadata" do
    expect { action.call(topic_name: "missing") }
      .to raise_error(Karafka::Pro::Actions::Errors::NotFoundError, "missing")
  end
end
