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
  subject(:contract) { described_class.new }

  let(:format_version) { Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator::FORMAT_VERSION }
  let(:version_message) do
    "needs to match the format this Karafka version builds. " \
      "Generate the report again with this Karafka version"
  end
  let(:report) do
    {
      "format_version" => format_version,
      "topic_name" => "orders",
      "settings" => { "concurrency" => 5 },
      "partitions" => { "0" => { "messages" => 10 } },
      "summary" => { "batches" => 1, "active_vps" => { "5" => 1 } }
    }
  end

  context "when report is valid" do
    it { expect(contract.call(report)).to be_success }
  end

  context "when only format_version is present" do
    let(:report) { { "format_version" => format_version } }

    it { expect(contract.call(report)).to be_success }
  end

  context "when the optional sections are null" do
    before do
      report["settings"] = nil
      report["partitions"] = nil
      report["summary"] = nil
    end

    it { expect(contract.call(report)).to be_success }
  end

  context "when format_version is missing" do
    before { report.delete("format_version") }

    it "explains the error" do
      expect(contract.call(report).errors).to eq(
        format_version: "needs to be present. Generate the report again with this Karafka version"
      )
    end
  end

  context "when report is not a Hash" do
    it { expect(contract.call([]).errors.keys).to eq(%i[format_version]) }
  end

  [0, 2, "1", 1.0, nil].each do |version|
    context "when format_version is #{version.inspect}" do
      before { report["format_version"] = version }

      it "explains the error" do
        expect(contract.call(report).errors).to eq(format_version: version_message)
      end
    end
  end

  context "when settings is not an object" do
    before { report["settings"] = "x" }

    it { expect(contract.call(report).errors).to eq(settings: "needs to be an object") }
  end

  context "when partitions is not an object" do
    before { report["partitions"] = [1, 2] }

    it "explains the error" do
      expect(contract.call(report).errors)
        .to eq(partitions: "needs to be an object with an object per partition")
    end
  end

  context "when a partition is null" do
    before { report["partitions"] = { "0" => nil } }

    it "explains the error" do
      expect(contract.call(report).errors)
        .to eq(partitions: "needs to be an object with an object per partition")
    end
  end

  context "when summary is not an object" do
    before { report["summary"] = 1 }

    it { expect(contract.call(report).errors).to eq(summary: "needs to be an object") }
  end

  context "when summary active_vps is not an object" do
    before { report["summary"]["active_vps"] = [1] }

    it { expect(contract.call(report).errors).to eq("summary.active_vps": "needs to be an object") }
  end

  [[1], true, "1", 1.5].each do |batches|
    context "when summary batches is #{batches.inspect}" do
      before { report["summary"]["batches"] = batches }

      it { expect(contract.call(report).errors).to eq("summary.batches": "needs to be an integer") }
    end
  end
end
