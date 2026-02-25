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
  include Karafka::Core::Helpers::Time

  subject(:manager) { described_class.new }

  let(:statistics) { JSON.parse(fixture_file("statistics.json")) }
  let(:listener_class) { Karafka::Connection::Listener }
  let(:listener_g11) { listener_class.new(subscription_group1, jobs_queue, nil) }
  let(:listener_g12) { listener_class.new(subscription_group2, jobs_queue, nil) }
  let(:listener_g21) { listener_class.new(subscription_group3, jobs_queue, nil) }
  let(:listener_g22) { listener_class.new(subscription_group4, jobs_queue, nil) }
  let(:routing_topic1) { build(:routing_topic) }
  let(:routing_topic2) { build(:routing_topic) }
  let(:routing_topic3) { build(:routing_topic) }
  let(:routing_topic4) { build(:routing_topic) }
  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:app) { Karafka::App }

  let(:subscription_group1) do
    build(:routing_subscription_group, name: "g1", topics: [routing_topic1])
  end

  let(:subscription_group2) do
    build(:routing_subscription_group, name: "g1", topics: [routing_topic2])
  end

  let(:subscription_group3) do
    build(:routing_subscription_group, name: "g2", topics: [routing_topic3])
  end

  let(:subscription_group4) do
    build(:routing_subscription_group, name: "g2", topics: [routing_topic4])
  end

  let(:listeners) do
    batch = Karafka::Connection::ListenersBatch.new(nil)
    batch.instance_variable_set(:@batch, [listener_g11, listener_g12, listener_g21, listener_g22])
    batch
  end

  before do
    Karafka::Connection::Status::STATES.each_value do |transition|
      listeners.each do |listener|
        allow(listener).to receive(transition).and_call_original
        allow(listener).to receive(:"#{transition}?").and_call_original
      end
    end

    listeners.each { |listener| allow(listener).to receive(:start!) }
  end

  describe "#register" do
    it "expect to start all listeners if none in multiplexed mode" do
      manager.register(listeners)

      expect(listeners).to all have_received(:start!)
    end

    context "when we operate in a non-dynamic multiplexed mode" do
      before do
        subscription_group1.multiplexing.active = true
        subscription_group1.multiplexing.min = 2
        subscription_group1.multiplexing.max = 2
        subscription_group1.multiplexing.boot = 2
      end

      it "expect to start all listeners" do
        manager.register(listeners)

        expect(listeners).to all have_received(:start!)
      end
    end

    context "when we operate in a dynamic multiplexed mode" do
      before do
        subscription_group1.multiplexing.active = true
        subscription_group1.multiplexing.min = 1
        subscription_group1.multiplexing.max = 2
        subscription_group1.multiplexing.boot = 1

        manager.register(listeners)
      end

      it "expect to start all non-dynamic" do
        expect(listener_g21).to have_received(:start!)
        expect(listener_g22).to have_received(:start!)
      end

      it "expect to start boot dynamic" do
        expect(listener_g11).to have_received(:start!)
        expect(listener_g12).not_to have_received(:start!)
      end
    end
  end

  describe "#notice" do
    let(:changes) { manager.instance_variable_get(:@changes) }
    let(:details) { changes.values.first }

    before { manager.register(listeners) }

    context "when notice was used" do
      before { manager.notice(subscription_group1.id, statistics) }

      it { expect(details[:state_age]).to eq(13_995) }
      it { expect(details[:join_state]).to eq("steady") }
      it { expect(details[:state]).to eq("up") }
      it { expect(monotonic_now - details[:changed_at]).to be < 50 }
    end
  end

  describe "#control" do
    before { allow(app).to receive(:done?).and_return(done) }

    context "when processing is done" do
      let(:done) { true }

      it "expect to run shutdown" do
        allow(manager).to receive(:shutdown)
        manager.control
        expect(manager).to have_received(:shutdown)
      end
    end

    context "when processing is not done" do
      let(:done) { false }

      it "expect to run rescale" do
        allow(manager).to receive(:rescale)
        manager.control
        expect(manager).to have_received(:rescale)
      end
    end
  end

  describe "#shutdown" do
    let(:quiet) { false }

    before do
      listener_g11.running!
      listener_g21.running!

      manager.register(listeners)

      allow(app).to receive_messages(
        done?: true,
        quiet?: quiet
      )
    end

    context "when under quiet" do
      before do
        allow(app).to receive_messages(
          done?: true,
          quieting?: true,
          quieted!: true
        )
      end

      context "when it just started" do
        before { manager.control }

        it { expect(listener_g11).to have_received(:quiet!) }
        it { expect(listener_g21).to have_received(:quiet!) }
        it { expect(listener_g12).not_to have_received(:quiet!) }
        it { expect(listener_g22).not_to have_received(:quiet!) }
      end

      context "when not all listeners are quieted" do
        it "expect not to switch process to quiet" do
          manager.control

          expect(app).not_to have_received(:quieted!)
        end
      end

      context "when all listeners are quieted" do
        before do
          allow(app).to receive(:quiet?).and_return(true)

          manager.control
          listeners.each(&:quieted!)
          manager.control
        end

        it "expect to switch whole process to quieted" do
          expect(app).to have_received(:quieted!)
        end

        it "expect not to move them forward to stopping" do
          listeners.each do |listener|
            expect(listener).not_to have_received(:stop!)
          end
        end
      end
    end

    context "when stopping" do
      before do
        allow(app).to receive_messages(
          done?: true,
          quieting?: true,
          quieted!: true,
          quiet?: false
        )
      end

      context "when it just started" do
        before { manager.control }

        it { expect(listener_g11).to have_received(:quiet!) }
        it { expect(listener_g21).to have_received(:quiet!) }
        it { expect(listener_g12).not_to have_received(:quiet!) }
        it { expect(listener_g22).not_to have_received(:quiet!) }
      end

      context "when not all listeners are quieted" do
        it "expect not to switch process to quiet" do
          manager.control

          expect(app).not_to have_received(:quieted!)
        end
      end

      context "when all listeners are quieted" do
        before do
          allow(app).to receive(:quiet?).and_return(false)

          manager.control
          listeners.each(&:quieted!)
          manager.control
        end

        it "expect to switch whole process to quieted" do
          expect(app).to have_received(:quieted!)
        end

        it "expect to move them forward to stopping" do
          expect(listeners).to all have_received(:stop!)
        end
      end

      context "when all listeners are stopped" do
        before do
          allow(app).to receive(:quiet?).and_return(false)

          manager.control
          listeners.each(&:stopped!)
          manager.control
        end

        it "expect to move them forward to stopping" do
          expect(listeners).to all have_received(:stopped!).twice
        end
      end
    end
  end

  describe "#scale_down" do
    let(:done) { false }
    let(:assignments) { {} }

    # Ignore scale up scenario completely in this scope
    before do
      allow(app).to receive(:assignments).and_return(assignments)
      allow(manager).to receive(:scale_up)
      manager.register(listeners)
      manager.notice(routing_topic1.subscription_group.id, statistics)
    end

    context "when there are no assignments" do
      before { manager.control }

      it do
        listeners.each do |listener|
          expect(listener).not_to have_received(:stop!)
        end
      end
    end

    context "when there are assignments that are maxed out and active but one with partition" do
      let(:assignments) { { routing_topic1 => [0] } }

      context "when multiplexing is off for this group" do
        before do
          subscription_group1.multiplexing.active = false
          manager.control
        end

        it "expect not to downscale" do
          listeners.each do |listener|
            expect(listener).not_to have_received(:stop!)
          end
        end
      end

      context "when multiplexing is on but not in dynamic mode" do
        before do
          subscription_group1.multiplexing.active = true
          subscription_group1.multiplexing.min = 5
          subscription_group1.multiplexing.max = 5
          manager.control
        end

        it "expect not to downscale" do
          listeners.each do |listener|
            expect(listener).not_to have_received(:stop!)
          end
        end
      end

      context "when multiplexing is on and in a dynamic mode and we could downscale" do
        before do
          subscription_group1.multiplexing.scale_delay = 0
          subscription_group1.multiplexing.active = true
          subscription_group1.multiplexing.min = 1
          subscription_group1.multiplexing.max = 5
          listeners.each(&:running!)

          listeners.each do |listener|
            manager.notice(listener.subscription_group.id, statistics)
          end

          manager.control
        end

        it "expect to downscale one listener out of stable group" do
          listeners.each.with_index do |listener, i|
            if i == 1
              expect(listener).to have_received(:stop!)
            else
              expect(listener).not_to have_received(:stop!)
            end
          end
        end
      end
    end
  end

  describe "#scale_up" do
    let(:done) { false }
    let(:assignments) { {} }

    # Ignore scale down scenario completely in this scope
    before do
      allow(app).to receive(:assignments).and_return(assignments)
      allow(manager).to receive(:scale_down)
      manager.register(listeners)
      manager.notice(routing_topic1.subscription_group.id, statistics)
    end

    context "when there are no assignments" do
      before { manager.control }

      it do
        listeners.each do |listener|
          expect(listener).not_to have_received(:stop!)
        end
      end
    end

    context "when there are assignments that are maxed out and active with many partitions" do
      let(:assignments) { { routing_topic1 => [0, 1, 2] } }

      context "when multiplexing is off for this group" do
        before do
          subscription_group1.multiplexing.active = false
          manager.control
        end

        it "expect not to upscale" do
          expect(listeners).to all have_received(:start!).once
        end
      end

      context "when multiplexing is on but not in dynamic mode" do
        before do
          subscription_group1.multiplexing.active = true
          subscription_group1.multiplexing.min = 5
          subscription_group1.multiplexing.max = 5
          manager.control
        end

        it "expect not to upscale" do
          expect(listeners).to all have_received(:start!).once
        end
      end

      context "when multiplexing is on and in a dynamic mode and we could upscale" do
        before do
          subscription_group1.multiplexing.scale_delay = 0
          subscription_group1.multiplexing.active = true
          subscription_group1.multiplexing.min = 1
          subscription_group1.multiplexing.max = 5
          listener_g11.running!
          listener_g12.stopped!
          manager.control
        end

        it "expect to upscale one listener out of stable group" do
          listeners.each.with_index do |listener, i|
            if i == 1
              expect(listener).to have_received(:start!).twice
            else
              expect(listener).to have_received(:start!).once
            end
          end
        end
      end
    end
  end
end
