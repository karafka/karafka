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

  before do
    allow(listener).to receive(:node).and_return(node)
    allow(node).to receive(:healthy)
    allow(node).to receive(:unhealthy)
  end

  describe "#initialize" do
    it "sets the memory_limit, consuming_ttl, and polling_ttl with provided values" do
      expect(listener_memory_limit).to eq(memory_limit)
      expect(listener_consuming_ttl).to eq(consuming_ttl)
      expect(listener_polling_ttl).to eq(polling_ttl)
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
