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
  subject(:runner) { described_class.new(adapter: "spec", registry: registry) }

  let(:registry) { Karafka::Pro::Actions::Registry.new }
  let(:action) do
    Class.new(Karafka::Pro::Actions::Read) do
      action_name "spec"
      description "Spec action"
      sources :broker
      arg :name, type: :string, description: "Name", required: true
      arg :count, type: :integer, description: "Count"

      def call(name:, count: 1)
        { name: name, count: count }
      end
    end
  end

  before do
    Karafka::Pro::Actions.post_setup(Karafka::App.config)
    registry.add(action)
  end

  context "when the action succeeds" do
    let(:result) { runner.call("spec", { "name" => "x", "count" => 2 }).to_h }

    it { expect(result[:ok]).to be(true) }
    it { expect(result[:data]).to eq(name: "x", count: 2) }
    it { expect(result[:meta][:sources]).to eq(["broker"]) }
    it { expect(result[:meta][:query_time_ms]).to be_a(Integer) }
  end

  context "when the action is paginated" do
    let(:action) do
      Class.new(Karafka::Pro::Actions::Read) do
        action_name "spec"
        paginated

        def call(page: nil, per_page: nil)
          paginate((1..5).to_a, page: page, per_page: per_page)
        end
      end
    end

    it "expect to move pagination details to meta" do
      result = runner.call("spec", { page: 2, per_page: 2 }).to_h

      expect(result[:data]).to eq([3, 4])
      expect(result[:meta]).to include(page: 2, per_page: 2, has_more: true)
    end

    it "expect to report the last page" do
      result = runner.call("spec", { page: 3, per_page: 2 }).to_h

      expect(result[:data]).to eq([5])
      expect(result[:meta][:has_more]).to be(false)
    end

    it "expect to return no rows past the last page" do
      expect(runner.call("spec", { page: 9 }).to_h[:data]).to eq([])
    end

    it "expect to reject a page size above the limit" do
      expect(runner.call("spec", { per_page: 1_001 }).error).to eq("invalid_args")
    end

    it "expect to reject a page below one" do
      expect(runner.call("spec", { page: 0 }).error).to eq("invalid_args")
    end
  end

  context "when the action is unknown" do
    let(:result) { runner.call("delete").to_h }

    it { expect(result[:ok]).to be(false) }
    it { expect(result[:error]).to eq("unknown_action") }
    it { expect(result[:details]).to eq(action: "delete") }
  end

  context "when a required argument is missing" do
    it { expect(runner.call("spec").to_h[:details]).to eq(value: "name") }
  end

  context "when an argument is not declared" do
    it { expect(runner.call("spec", { name: "x", other: 1 }).to_h[:details]).to eq(value: "other") }
  end

  context "when an argument has a wrong type" do
    it { expect(runner.call("spec", { name: "x", count: "2" }).error).to eq("invalid_args") }
  end

  context "when the action fails" do
    let(:action) do
      Class.new(Karafka::Pro::Actions::Read) do
        action_name "spec"

        def call
          raise StandardError, "a" * 1_000
        end
      end
    end

    let(:result) { runner.call("spec").to_h }

    it { expect(result[:error]).to eq("failed") }
    it { expect(result[:details][:class]).to eq("StandardError") }
    it { expect(result[:details][:message].size).to eq(500) }
  end

  context "when the action raises not found" do
    let(:action) do
      Class.new(Karafka::Pro::Actions::Read) do
        action_name "spec"

        def call
          raise Karafka::Pro::Actions::Errors::NotFoundError, "topic"
        end
      end
    end

    it { expect(runner.call("spec").to_h).to include(error: "not_found", details: { value: "topic" }) }
  end

  context "when instrumenting" do
    let(:events) { [] }

    before do
      Karafka.monitor.subscribe("actions.action.executed") { |event| events << event }
    end

    after { Karafka.monitor.notifications_bus.clear("actions.action.executed") }

    it "expect to publish the execution with its result" do
      result = runner.call("spec", { name: "x" })

      expect(events.size).to eq(1)
      expect(events.first[:action]).to eq("spec")
      expect(events.first[:args]).to eq(name: "x")
      expect(events.first[:adapter]).to eq("spec")
      expect(events.first[:result]).to eq(result)
      expect(events.first[:time]).to be_a(Numeric)
    end
  end
end
