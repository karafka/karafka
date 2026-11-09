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
  let(:registry) { Karafka::Pro::Actions::Registry.new }
  let(:read_actions) do
    described_class.post_setup(Karafka::App.config)
    registry.to_a
  end

  before { allow(described_class).to receive(:registry).and_return(registry) }

  describe ".post_setup" do
    it "expect to register core actions" do
      described_class.post_setup(Karafka::App.config)

      expect(registry.map(&:action_name)).to eq(%w[cluster lags routing topic topics])
    end

    it "expect to register the execution event once" do
      2.times { described_class.post_setup(Karafka::App.config) }

      expect(Karafka.monitor.notifications_bus.available_events)
        .to include("action.executed")
    end
  end

  describe "read-only guarantees" do
    let(:forbidden) { /\bAdmin\b|Rdkafka|WaterDrop|[Pp]roducer|Commanding/ }

    it "expect every core action to be a read action" do
      expect(read_actions).to all(be < Karafka::Pro::Actions::Read)
    end

    it "expect the check to catch direct and relative references" do
      violations = [
        "Karafka::Admin.delete_topic(name)",
        "Admin::Topics.delete(name)",
        "::Rdkafka::Config.new({}).admin",
        "Karafka.producer.produce_sync(topic: name)",
        "WaterDrop::Producer.new",
        "Web::Pro::Commanding::Dispatcher.request"
      ]

      expect(violations).to all(match(forbidden))
      expect(forbidden.match?("admin.cluster_info")).to be(false)
      expect(forbidden.match?("ReadOnlyAdmin.new")).to be(false)
    end

    it "expect read actions not to reference Admin, rdkafka, producers or commanding" do
      read_actions.each do |action|
        source = File
          .readlines(Object.const_source_location(action.name).first)
          .reject { |line| line.strip.start_with?("#") }
          .join

        expect(source).not_to match(forbidden), action.name
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

  # Agents and scripts depend on the arguments and output shapes, so they are a public API. When
  # these snapshots change, `Result::SCHEMA_VERSION` has to change as well.
  describe "snapshots of the current schema version" do
    let(:arguments_snapshot) do
      {
        "cluster" => [[], []],
        "lags" => [%w[consumer_group_id topic_name page per_page], []],
        "routing" => [[], []],
        "topic" => [%w[topic_name], %w[topic_name]],
        "topics" => [%w[pattern page per_page], []]
      }
    end

    let(:output_snapshot) do
      {
        "cluster" => %i[brokers cluster_id controller],
        "lags" => %i[consumer_group_id lag_committed offset_committed partition topic],
        "routing" => %i[
          active consumer group_id group_type source_location subscription_group_id topic
        ],
        "topic" => {
          keys: %i[configs partition_count partitions topic],
          partitions: %i[
            high_watermark in_sync_replicas leader low_watermark partition replicas
          ],
          configs: %i[default name read_only sensitive value]
        },
        "topics" => %i[partition_count topic]
      }
    end

    let(:admin) { instance_double(Karafka::Pro::Actions::ReadOnlyAdmin) }
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
    let(:topic) { Struct.new(:name, :consumer, :active?).new("orders", nil, true) }
    let(:subscription_group) { Struct.new(:id, :topics).new("sg", [topic]) }
    let(:group) do
      Struct.new(:id, :group_type, :subscription_groups, :topics)
        .new("cg", :consumer, [subscription_group], [topic])
    end

    before do
      allow(Karafka::App).to receive(:routes).and_return([group])
      allow(Karafka::App.routes).to receive(:consumer_groups).and_return([group])
      allow(admin).to receive_messages(
        describe_cluster: { cluster_id: "c", controller: {}, brokers: [] },
        cluster_info: metadata,
        read_watermark_offsets: { "orders" => { 0 => [0, 1] } },
        describe_topic_configs: [Karafka::Admin::Configs::Config.new(name: "a", value: "b")],
        read_lags_with_offsets: { "cg" => { "orders" => { 0 => { offset: 0, lag: 1 } } } }
      )
    end

    it "expect the actions arguments to match the snapshot" do
      catalog = read_actions.to_h do |action|
        schema = action.schema

        [action.action_name, [schema[:properties].keys, schema[:required]]]
      end

      expect(catalog).to eq(arguments_snapshot)
    end

    it "expect the actions outputs to match the snapshot" do
      outputs = read_actions.to_h do |action|
        args = (action == Karafka::Pro::Actions::Topic) ? { topic_name: "orders" } : {}
        output = action.new(admin: admin).call(**args)
        output = output.rows.first if output.is_a?(Karafka::Pro::Actions::Base::Page)
        output = output.first if output.is_a?(Array)

        [action.action_name, output]
      end

      shapes = outputs.to_h do |name, output|
        next [name, output.keys.sort] unless name == "topic"

        [
          name,
          {
            keys: output.keys.sort,
            partitions: output[:partitions].first.keys.sort,
            configs: output[:configs].first.keys.sort
          }
        ]
      end

      expect(shapes).to eq(output_snapshot)
    end

    it "expect the envelope keys to match the snapshot" do
      success = Karafka::Pro::Actions::Result.new(success: true, data: [], meta: {})
      failure = Karafka::Pro::Actions::Result.new(success: false, error: "failed", details: {})

      expect(success.to_h.keys).to eq(%i[schema_version ok data meta])
      expect(failure.to_h.keys).to eq(%i[schema_version ok error details meta])
    end

    it { expect(Karafka::Pro::Actions::Result::SCHEMA_VERSION).to eq(1) }
  end
end
