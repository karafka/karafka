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
  let(:actions_dir) { Karafka.core_root.join("pro/actions") }
  let(:read_actions) do
    Karafka::Pro::Actions::Registry
      .new
      .tap { |registry| described_class.send(:const_get, :CORE).each { |a| registry.add(a) } }
      .to_a
  end

  describe ".post_setup" do
    let(:registry) { Karafka::Pro::Actions::Registry.new }

    before { allow(described_class).to receive(:registry).and_return(registry) }

    it "expect to register core actions" do
      described_class.post_setup(Karafka::App.config)

      expect(registry.map(&:action_name)).to eq(%w[cluster lags routing topic topics])
    end

    it "expect to register the execution event once" do
      2.times { described_class.post_setup(Karafka::App.config) }

      expect(Karafka.monitor.notifications_bus.available_events)
        .to include("actions.action.executed")
    end
  end

  describe "read-only guarantees" do
    it "expect every core action to be a read action" do
      expect(read_actions).to all(be < Karafka::Pro::Actions::Read)
    end

    it "expect read actions not to reference Admin, producers or commanding directly" do
      read_actions.each do |action|
        source = File
          .readlines(Object.const_source_location(action.name).first)
          .reject { |line| line.strip.start_with?("#") }
          .join

        expect(source).not_to match(/Karafka::Admin|Admin\.|producer|Commanding/)
      end
    end
  end

  describe "arguments schemas" do
    it "expect each action to produce a valid JSON Schema object" do
      read_actions.each do |action|
        schema = action.schema

        expect(schema[:type]).to eq("object")
        expect(schema[:additionalProperties]).to be(false)
        expect(schema[:properties].values.map { |p| p[:type] }).to all(eq("string").or(eq("integer")))
        expect(schema[:properties].values.map { |p| p[:description] }).to all(be_a(String))
        expect(schema[:required] - schema[:properties].keys).to be_empty
        expect { JSON.generate(schema) }.not_to raise_error
      end
    end
  end

  # Agents and scripts depend on the output shape, so it is a public API. When this snapshot
  # changes, `Result::SCHEMA_VERSION` has to change as well.
  describe "catalog snapshot" do
    let(:snapshot) do
      {
        "cluster" => [[], []],
        "lags" => [%w[consumer_group_id topic_name page per_page], []],
        "routing" => [[], []],
        "topic" => [%w[topic_name], %w[topic_name]],
        "topics" => [%w[pattern page per_page], []]
      }
    end

    it "expect the actions arguments to match the snapshot of the current schema version" do
      catalog = read_actions.to_h do |action|
        schema = action.schema

        [action.action_name, [schema[:properties].keys, schema[:required]]]
      end

      expect(catalog).to eq(snapshot)
      expect(Karafka::Pro::Actions::Result::SCHEMA_VERSION).to eq(1)
    end
  end
end
