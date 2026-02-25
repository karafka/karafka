# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:deserializer) { described_class.new }

  let(:metadata) { instance_double(Karafka::Messages::Metadata, raw_headers: raw_headers) }

  context "when headers are valid" do
    let(:raw_headers) do
      {
        "schedule_source_type" => "schedule",
        "schedule_target_epoch" => "1679330400",
        "schedule_target_partition" => "3"
      }
    end

    it "converts schedule_target_epoch to an integer" do
      expect(deserializer.call(metadata)["schedule_target_epoch"]).to be_a(Integer)
      expect(deserializer.call(metadata)["schedule_target_epoch"]).to eq(1_679_330_400)
    end

    it "converts schedule_target_partition to an integer" do
      expect(deserializer.call(metadata)["schedule_target_partition"]).to be_a(Integer)
      expect(deserializer.call(metadata)["schedule_target_partition"]).to eq(3)
    end
  end

  context "when headers include tombstone events" do
    let(:raw_headers) do
      {
        "schedule_source_type" => "tombstone",
        "schedule_target_epoch" => "1679330400",
        "schedule_target_partition" => "3"
      }
    end

    it "converts schedule_target_epoch to an integer" do
      expect(deserializer.call(metadata)["schedule_target_epoch"]).to be_a(Integer)
      expect(deserializer.call(metadata)["schedule_target_epoch"]).to eq(1_679_330_400)
    end

    it "converts schedule_target_partition to an integer" do
      expect(deserializer.call(metadata)["schedule_target_partition"]).to be_a(Integer)
      expect(deserializer.call(metadata)["schedule_target_partition"]).to eq(3)
    end
  end

  context "when headers include cancel events" do
    let(:raw_headers) do
      {
        "schedule_source_type" => "cancel",
        "schedule_target_epoch" => "1679330400",
        "schedule_target_partition" => "3"
      }
    end

    it "does not convert any header fields" do
      expect(deserializer.call(metadata)).to eq(raw_headers)
    end
  end

  context "when schedule_target_partition is missing" do
    let(:raw_headers) do
      {
        "schedule_source_type" => "schedule",
        "schedule_target_epoch" => "1679330400"
      }
    end

    it "does not add schedule_target_partition to the headers" do
      expect(deserializer.call(metadata)).not_to have_key("schedule_target_partition")
    end
  end

  context "when schedule_target_epoch is not a string" do
    let(:raw_headers) do
      {
        "schedule_source_type" => "schedule",
        "schedule_target_epoch" => 1_679_330_400
      }
    end

    it "does not change the value" do
      expect(deserializer.call(metadata)["schedule_target_epoch"]).to eq(1_679_330_400)
    end
  end
end
