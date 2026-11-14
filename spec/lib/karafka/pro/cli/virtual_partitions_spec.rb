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
  subject(:command) { described_class.new }

  let(:report_cmd) { Karafka::Pro::Cli::VirtualPartitions::EstimateReport }
  let(:report_instance) { instance_double(report_cmd, call: nil) }

  before { allow(report_cmd).to receive(:new).and_return(report_instance) }

  it { expect(described_class.names).to include("virtual_partitions", "vps") }

  describe "#call" do
    context 'when action is "estimate-report"' do
      before { stub_const("ARGV", %w[vps estimate-report]) }

      it "displays the default report" do
        command.call("estimate-report")

        expect(report_cmd).to have_received(:new).with(nil)
        expect(report_instance).to have_received(:call)
      end

      it 'assumes "estimate-report" as default action when none provided' do
        command.call

        expect(report_cmd).to have_received(:new).with(nil)
      end
    end

    context "when a path is given after the action" do
      before { stub_const("ARGV", %w[vps estimate-report path/to/file.json]) }

      it "displays the given report" do
        command.call("estimate-report")

        expect(report_cmd).to have_received(:new).with("path/to/file.json")
      end
    end

    context "when the report cannot be displayed" do
      before do
        stub_const("ARGV", %w[vps estimate-report])
        allow(report_instance)
          .to receive(:call)
          .and_raise(Karafka::Errors::CommandValidationError, "Estimate report is not valid: x")
      end

      it "prints the error and exits with an error" do
        expect { command.call("estimate-report") }
          .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
          .and output("Estimate report is not valid: x\n").to_stdout
      end
    end

    context "when the report file is missing" do
      before do
        allow(report_cmd).to receive(:new).and_call_original
        stub_const("ARGV", %w[vps estimate-report /nonexistent/report.json])
      end

      it "raises the system error" do
        expect { command.call("estimate-report") }.to raise_error(Errno::ENOENT)
      end
    end

    context 'when action is "help"' do
      it "prints the available actions" do
        expect { command.call("help") }
          .to output(/estimate-report \[path\].*\n.*help/).to_stdout
      end
    end

    context "when action is invalid" do
      it "raises UnrecognizedCommandError with appropriate message" do
        expect { command.call("invalid_action") }.to raise_error(
          Karafka::Errors::UnrecognizedCommandError,
          "Unrecognized virtual partitions action: invalid_action"
        )
      end
    end
  end
end
