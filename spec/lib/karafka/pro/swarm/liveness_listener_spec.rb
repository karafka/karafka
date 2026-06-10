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
  subject(:listener) do
    described_class.new(
      memory_limit: memory_limit,
      consuming_ttl: consuming_ttl,
      polling_ttl: polling_ttl
    )
  end

  let(:memory_limit) { Float::INFINITY }
  let(:consuming_ttl) { 5 * 60 * 1000 }
  let(:polling_ttl) { 5 * 60 * 1000 }
  let(:event) { {} }
  let(:node) { build(:swarm_node) }
  let(:listener_memory_limit) { listener.instance_variable_get(:@memory_limit) }
  let(:listener_consuming_ttl) { listener.instance_variable_get(:@consuming_ttl) }
  let(:listener_polling_ttl) { listener.instance_variable_get(:@polling_ttl) }
  let(:listener_pollings) { listener.instance_variable_get(:@pollings) }
  let(:listener_consumptions) { listener.instance_variable_get(:@consumptions) }
  let(:listener_instabilities) { listener.instance_variable_get(:@instabilities) }
  let(:listener_join_states) { listener.instance_variable_get(:@join_states) }

  def stats_event(join_state:, sg_id: "sg1")
    { subscription_group_id: sg_id, statistics: { "cgrp" => { "join_state" => join_state } } }
  end

  before do
    allow(listener).to receive(:node).and_return(node)
    allow(node).to receive(:healthy)
    allow(node).to receive(:unhealthy)
    allow(node).to receive(:orphaned?).and_return(false)
  end

  describe "#initialize" do
    it "sets the memory_limit, consuming_ttl, and polling_ttl with provided values" do
      expect(listener_memory_limit).to eq(memory_limit)
      expect(listener_consuming_ttl).to eq(consuming_ttl)
      expect(listener_polling_ttl).to eq(polling_ttl)
    end

    it "initializes instabilities as an empty hash" do
      expect(listener_instabilities).to eq({})
    end
  end

  describe "#on_connection_listener_fetch_loop" do
    it "marks a polling tick" do
      expect { listener.on_connection_listener_fetch_loop(event) }
        .to change(listener_pollings, :size).by(1)
    end
  end

  # Example for consume event, similar approach for revoke, shutting_down, and tick
  describe "#on_consumer_consume" do
    it "marks a consumption tick" do
      expect { listener.on_consumer_consume(event) }
        .to change(listener_consumptions, :size).by(1)
    end
  end

  describe "#on_error_occurred" do
    it "clears consumption and polling ticks" do
      # Set up initial state
      listener.on_connection_listener_fetch_loop(event)
      listener.on_consumer_consume(event)

      expect { listener.on_error_occurred(event) }
        .to change(listener_pollings, :empty?).from(false).to(true)
        .and change(listener_consumptions, :empty?).from(false).to(true)
    end
  end

  describe "#on_client_events_poll" do
    it "reports healthy status" do
      listener.on_client_events_poll(event)
      expect(node).to have_received(:healthy)
    end

    context "when node becomes orphaned" do
      before do
        allow(node).to receive(:orphaned?).and_return(true)
        allow(Kernel).to receive(:exit!)
      end

      it "exits with orphaned exit code" do
        listener.on_client_events_poll(event)
        expect(Kernel).to have_received(:exit!).with(3)
      end
    end
  end

  describe "#on_connection_listener_before_fetch_loop" do
    it "reports healthy status" do
      listener.on_connection_listener_before_fetch_loop(event)
      expect(node).to have_received(:healthy)
    end
  end

  describe "fiber-safety" do
    it "tracks polling timestamps independently per fiber" do
      fiber1_id = nil
      fiber2_id = nil

      f1 = Fiber.new do
        fiber1_id = Fiber.current.object_id
        listener.on_connection_listener_fetch_loop(event)
      end

      f2 = Fiber.new do
        fiber2_id = Fiber.current.object_id
        listener.on_connection_listener_fetch_loop(event)
      end

      f1.resume
      f2.resume

      expect(listener_pollings.keys).to contain_exactly(fiber1_id, fiber2_id)
    end

    it "tracks consumption timestamps independently per fiber" do
      fiber1_id = nil
      fiber2_id = nil

      f1 = Fiber.new do
        fiber1_id = Fiber.current.object_id
        listener.on_consumer_consume(event)
      end

      f2 = Fiber.new do
        fiber2_id = Fiber.current.object_id
        listener.on_consumer_consume(event)
      end

      f1.resume
      f2.resume

      expect(listener_consumptions.keys).to contain_exactly(fiber1_id, fiber2_id)
    end

    it "clearing in one fiber does not remove the other fibers timestamp" do
      f1 = Fiber.new do
        listener.on_consumer_consume(event)
        Fiber.yield
        listener.on_consumer_consumed(event)
      end

      f2 = Fiber.new do
        listener.on_consumer_consume(event)
      end

      # Both fibers mark consumption
      f1.resume
      f2.resume
      expect(listener_consumptions.size).to eq(2)

      # Only f1 clears its entry
      f1.resume
      expect(listener_consumptions.size).to eq(1)
    end
  end

  describe "#on_statistics_emitted" do
    context "when join_state is steady" do
      it "clears any existing non-steady tracking for that subscription group" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener_instabilities).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "steady"))
        expect(listener_instabilities).to be_empty
      end

      it "clears the join_states entry when the consumer recovers" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener_join_states).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "steady"))
        expect(listener_join_states).to be_empty
      end
    end

    context "when join_state is non-steady" do
      it "records when the group first became non-steady" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
        expect(listener_instabilities["sg1"]).to be_a(Numeric)
      end

      it "does not reset the start time when the same non-steady state repeats" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
        first_tick = listener_instabilities["sg1"]

        sleep(0.01)
        listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
        expect(listener_instabilities["sg1"]).to eq(first_tick)
      end

      it "resets the start time when the non-steady state changes" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
        first_tick = listener_instabilities["sg1"]

        sleep(0.01)
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener_instabilities["sg1"]).to be > first_tick
      end
    end

    context "when statistics have no cgrp key" do
      it "ignores the event" do
        event_without_cgrp = { subscription_group_id: "sg1", statistics: {} }
        listener.on_statistics_emitted(event_without_cgrp)
        expect(listener_instabilities).to be_empty
      end
    end

    context "when cgrp is present but join_state is nil" do
      it "ignores the event without starting an instability timer" do
        event = { subscription_group_id: "sg1", statistics: { "cgrp" => { "join_state" => nil } } }
        listener.on_statistics_emitted(event)
        expect(listener_instabilities).to be_empty
      end
    end

    context "when join_state is init" do
      it "does not start an instability timer for a fresh subscription group" do
        listener.on_statistics_emitted(stats_event(join_state: "init"))
        expect(listener_instabilities).to be_empty
      end

      it "clears any existing instability entry on rdkafka client reset" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener_instabilities).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "init"))
        expect(listener_instabilities).to be_empty
      end

      it "clears the join_states entry on rdkafka client reset" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener_join_states).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "init"))
        expect(listener_join_states).to be_empty
      end
    end

    context "when join_state is wait-metadata" do
      it "does not start an instability timer for a fresh subscription group" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-metadata"))
        expect(listener_instabilities).to be_empty
      end

      it "clears any existing instability entry so the prior timer cannot fire later" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener_instabilities).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "wait-metadata"))
        expect(listener_instabilities).to be_empty
      end

      it "clears the join_states entry when the consumer moves into wait-metadata" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener_join_states).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "wait-metadata"))
        expect(listener_join_states).to be_empty
      end
    end

    context "when event[:statistics] is nil (defensive)" do
      it "does not raise" do
        expect do
          listener.on_statistics_emitted(subscription_group_id: "sg1", statistics: nil)
        end.not_to raise_error
        expect(listener_instabilities).to be_empty
      end
    end
  end

  describe "#status" do
    context "when stability_ttl is exceeded" do
      subject(:listener) do
        described_class.new(
          memory_limit: memory_limit,
          consuming_ttl: consuming_ttl,
          polling_ttl: polling_ttl,
          stability_ttl: 0
        )
      end

      before { allow(listener).to receive(:node).and_return(node) }

      it "returns status code 4" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener.send(:status)).to eq(4)
      end
    end

    context "when nothing is exceeded" do
      it "returns 0" do
        expect(listener.send(:status)).to eq(0)
      end
    end
  end

  describe "default stability_ttl derivation" do
    # The outer `before` accesses `listener`, which would memoize it before any per-example
    # config stubs apply. We use a separate `fresh_listener` let so it is realized lazily
    # in the it block (after any inner-context `before` stubs run).
    let(:fresh_listener) do
      described_class.new(
        memory_limit: memory_limit,
        consuming_ttl: consuming_ttl,
        polling_ttl: polling_ttl,
        **provided_stability_ttl_kwarg
      )
    end
    let(:provided_stability_ttl_kwarg) { {} }
    let(:fresh_listener_stability_ttl) { fresh_listener.instance_variable_get(:@stability_ttl) }

    context "when stability_ttl is not provided" do
      it "derives the default as max.poll.interval.ms * 2 using librdkafka's default" do
        expect(fresh_listener_stability_ttl).to eq(300_000 * 2)
      end

      context "when Karafka::App.config.kafka explicitly sets max.poll.interval.ms" do
        before do
          allow(Karafka::App.config).to receive(:kafka).and_return(
            :"max.poll.interval.ms" => 900_000
          )
        end

        it "uses the configured value times 2" do
          expect(fresh_listener_stability_ttl).to eq(900_000 * 2)
        end
      end

      context "when DefaultsInjector fills in the librdkafka default" do
        before { allow(Karafka::App.config).to receive(:kafka).and_return({}) }

        it "results in 600_000 ms (5 min * 2) when the user hasn't set the key" do
          expect(fresh_listener_stability_ttl).to eq(600_000)
        end
      end
    end

    context "when stability_ttl is explicitly provided" do
      let(:provided_stability_ttl_kwarg) { { stability_ttl: 12_345 } }

      it "uses the provided value verbatim and does not derive" do
        expect(fresh_listener_stability_ttl).to eq(12_345)
      end

      it "does not invoke DefaultsInjector for the derivation path" do
        expect(Karafka::Setup::DefaultsInjector).not_to receive(:consumer)
        fresh_listener
      end
    end
  end

  describe "#rss_mb" do
    it "delegates to platform-specific method based on RUBY_PLATFORM" do
      allow(listener).to receive_messages(rss_mb_linux: 50, rss_mb_macos: 60)

      if RUBY_PLATFORM.include?("linux")
        expect(listener.send(:rss_mb)).to eq(50)
        expect(listener).to have_received(:rss_mb_linux)
      else
        expect(listener.send(:rss_mb)).to eq(60)
        expect(listener).to have_received(:rss_mb_macos)
      end
    end
  end
end
