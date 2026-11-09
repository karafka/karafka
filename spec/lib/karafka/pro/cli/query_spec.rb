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

  let(:registry) { Karafka::Pro::Actions::Registry.new }
  let(:stdout_file) { Tempfile.create("query").tap { |file| file.sync = true } }
  let(:result) { JSON.parse(File.read(stdout_file.path)) }
  let(:action) do
    Class.new(Karafka::Pro::Actions::Read) do
      action_name "spec"
      description "Spec action"
      arg :topic_name, type: :string, description: "Topic", required: true
      arg :count, type: :integer, description: "Count"

      def call(topic_name:, count: 1)
        { topic: topic_name, count: count }
      end
    end
  end

  before do
    Karafka::Pro::Actions.post_setup(Karafka::App.config)
    registry.add(action)
    allow(Karafka::Pro::Actions).to receive(:registry).and_return(registry)
    $stdout = stdout_file
  end

  after { $stdout = STDOUT }

  def run(*argv)
    stub_const("ARGV", ["query", *argv])
    command.call(argv.first&.start_with?("-") ? nil : argv.first)
  end

  def exit_status(*argv)
    run(*argv)
  rescue SystemExit => e
    e.status
  end

  it { expect(described_class.names).to eq(["query"]) }

  context "when no action is given" do
    before { run("--help", "--json") }

    it { expect(result["ok"]).to be(true) }
    it { expect(result["data"]["actions"].map { |a| a["name"] }).to eq(["spec"]) }
    it { expect(result["data"]["actions"].first["args"]["required"]).to eq(["topic_name"]) }
  end

  context "when help is the action" do
    before { run("help") }

    it { expect(result["data"]["actions"].size).to eq(1) }
  end

  context "when running an action with flags" do
    before { run("spec", "--topic-name", "orders", "--count", "3", "--json") }

    it { expect(result["ok"]).to be(true) }
    it { expect(result["data"]).to eq("topic" => "orders", "count" => 3) }
  end

  context "when asking for help of an action" do
    before { run("spec", "--help") }

    it { expect(result["data"]["name"]).to eq("spec") }
  end

  context "when a flag is unknown" do
    it { expect(exit_status("spec", "--other", "x")).to eq(2) }

    it "expect to print invalid_args" do
      exit_status("spec", "--other", "x")

      expect(result).to include("ok" => false, "error" => "invalid_args")
    end
  end

  context "when an integer flag has a wrong value" do
    it { expect(exit_status("spec", "--topic_name", "x", "--count", "x")).to eq(2) }
  end

  context "when a positional argument is given" do
    it { expect(exit_status("spec", "orders")).to eq(2) }
  end

  context "when a required flag is missing" do
    it { expect(exit_status("spec")).to eq(2) }
  end

  context "when the command line cannot be parsed" do
    def details(*argv)
      exit_status(*argv)

      result["details"]
    end

    it "expect to key an unknown flag by its argument name" do
      expect(details("spec", "--other-flag", "x"))
        .to eq("errors" => { "other_flag" => "is not an argument of this action" })
    end

    it "expect to key a wrong value by the declared argument name" do
      expect(details("spec", "--topic_name", "x", "--count", "x"))
        .to eq("errors" => { "count" => "has a wrong type or format" })
    end

    it "expect a dashed flag to use the declared argument name" do
      expect(details("spec", "--topic_name", "x", "--count", "x").fetch("errors").keys)
        .to eq(details("spec", "--topic-name", "x", "--count", "x").fetch("errors").keys)
    end

    it "expect a flag with an inline value to use the declared argument name" do
      expect(details("spec", "--topic_name", "x", "--count=x"))
        .to eq("errors" => { "count" => "has a wrong type or format" })
    end

    it "expect a single dash flag to use its name" do
      expect(details("spec", "-x"))
        .to eq("errors" => { "x" => "is not an argument of this action" })
    end

    it "expect a flag without a value to be reported as required" do
      expect(details("spec", "--topic_name"))
        .to eq("errors" => { "topic_name" => "needs to be present" })
    end

    it "expect a positional argument to be reported as unknown" do
      expect(details("spec", "orders"))
        .to eq("errors" => { "orders" => "is not an argument of this action" })
    end
  end

  context "when flags come before the action" do
    it { expect(exit_status("--json", "spec")).to eq(2) }

    it "expect to print invalid_args instead of the catalog" do
      exit_status("--json", "spec")

      expect(result).to include("error" => "invalid_args", "details" => { "errors" => { "spec" => "needs an action before it" } })
    end

    it "expect to key a flag before the action by its argument name" do
      exit_status("--per-page=5", "spec")

      expect(result["details"]).to eq("errors" => { "per_page" => "needs an action before it" })
    end
  end

  context "when the action writes to stdout" do
    let(:action) do
      Class.new(Karafka::Pro::Actions::Read) do
        action_name "spec"

        def call
          $stdout.puts("log line")
          Karafka.logger.info("log line")
          { done: true }
        end
      end
    end

    it "expect stdout to hold only the envelope" do
      expect { run("spec") }.to output(/log line/).to_stderr_from_any_process

      expect(File.read(stdout_file.path).lines.size).to eq(1)
      expect(result["data"]).to eq("done" => true)
    end
  end

  context "when the action is unknown" do
    it { expect(exit_status("delete")).to eq(2) }

    it "expect to print unknown_action" do
      exit_status("delete")

      expect(result["error"]).to eq("unknown_action")
    end
  end

  context "when the resource is not found" do
    let(:action) do
      Class.new(Karafka::Pro::Actions::Read) do
        action_name "spec"

        def call
          raise Karafka::Pro::Actions::Errors::NotFoundError, "x"
        end
      end
    end

    it { expect(exit_status("spec")).to eq(3) }
  end

  context "when the action fails" do
    let(:action) do
      Class.new(Karafka::Pro::Actions::Read) do
        action_name "spec"

        def call
          raise StandardError
        end
      end
    end

    it { expect(exit_status("spec")).to eq(1) }
  end
end
