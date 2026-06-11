# frozen_string_literal: true

require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

# This is fully covered in the integration suite
RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:event) { {} }
  let(:pollings) { listener.instance_variable_get(:@pollings) }
  let(:consumptions) { listener.instance_variable_get(:@consumptions) }
  let(:instabilities) { listener.instance_variable_get(:@instabilities) }
  let(:join_states) { listener.instance_variable_get(:@join_states) }

  def stats_event(join_state:, sg_id: "sg1")
    { subscription_group_id: sg_id, statistics: { "cgrp" => { "join_state" => join_state } } }
  end

  describe "events mapping" do
    it { expect(NotificationsChecker.valid?(listener)).to be(true) }
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

      expect(pollings.keys).to contain_exactly(fiber1_id, fiber2_id)
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

      expect(consumptions.keys).to contain_exactly(fiber1_id, fiber2_id)
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
      expect(consumptions.size).to eq(2)

      # Only f1 clears its entry
      f1.resume
      expect(consumptions.size).to eq(1)
    end
  end

  describe "#on_statistics_emitted" do
    context "when join_state is steady" do
      it "does not add an entry to instabilities" do
        listener.on_statistics_emitted(stats_event(join_state: "steady"))
        expect(instabilities).to be_empty
      end

      it "removes a pre-existing instability entry when the consumer recovers" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(instabilities).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "steady"))
        expect(instabilities).to be_empty
      end

      it "removes a pre-existing join_states entry when the consumer recovers" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(join_states).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "steady"))
        expect(join_states).to be_empty
      end
    end

    context "when join_state is non-steady" do
      it "records a start timestamp for the subscription group" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
        expect(instabilities["sg1"]).to be_a(Numeric)
      end

      it "does not reset the start timestamp when the same non-steady state repeats" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
        first_tick = instabilities["sg1"]

        sleep(0.01)
        listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
        expect(instabilities["sg1"]).to eq(first_tick)
      end

      it "resets the start timestamp when the non-steady state changes" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
        first_tick = instabilities["sg1"]

        sleep(0.01)
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(instabilities["sg1"]).to be > first_tick
      end

      it "tracks each subscription group independently" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-join", sg_id: "sg1"))
        listener.on_statistics_emitted(stats_event(join_state: "wait-join", sg_id: "sg2"))
        listener.on_statistics_emitted(stats_event(join_state: "steady", sg_id: "sg1"))

        expect(instabilities.key?("sg1")).to be(false)
        expect(instabilities.key?("sg2")).to be(true)
      end
    end

    context "when statistics have no cgrp key (producer-side stats)" do
      it "ignores the event" do
        listener.on_statistics_emitted(subscription_group_id: "sg1", statistics: {})
        expect(instabilities).to be_empty
      end
    end

    context "when cgrp is present but join_state is nil" do
      it "ignores the event without starting an instability timer" do
        event = { subscription_group_id: "sg1", statistics: { "cgrp" => { "join_state" => nil } } }
        listener.on_statistics_emitted(event)
        expect(instabilities).to be_empty
      end
    end

    context "when join_state is init" do
      it "does not start an instability timer for a fresh subscription group" do
        listener.on_statistics_emitted(stats_event(join_state: "init"))
        expect(instabilities).to be_empty
      end

      it "clears any existing instability entry on rdkafka client reset" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(instabilities).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "init"))
        expect(instabilities).to be_empty
      end

      it "clears the join_states entry on rdkafka client reset" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(join_states).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "init"))
        expect(join_states).to be_empty
      end
    end

    context "when join_state is wait-metadata" do
      it "does not start an instability timer for a fresh subscription group" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-metadata"))
        expect(instabilities).to be_empty
      end

      it "clears any existing instability entry so the prior timer cannot fire later" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(instabilities).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "wait-metadata"))
        expect(instabilities).to be_empty
      end

      it "clears the join_states entry when the consumer moves into wait-metadata" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(join_states).not_to be_empty

        listener.on_statistics_emitted(stats_event(join_state: "wait-metadata"))
        expect(join_states).to be_empty
      end
    end

    context "when event[:statistics] is nil (defensive)" do
      it "does not raise" do
        expect do
          listener.on_statistics_emitted(subscription_group_id: "sg1", statistics: nil)
        end.not_to raise_error
        expect(instabilities).to be_empty
      end
    end
  end

  describe "#healthy?" do
    context "when stability_ttl is exceeded" do
      subject(:listener) { described_class.new(stability_ttl: 0) }

      it "returns false" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        expect(listener.healthy?).to be(false)
      end
    end

    context "when stability_ttl is not exceeded" do
      it "returns true when no non-steady state is tracked" do
        expect(listener.healthy?).to be(true)
      end

      it "returns true when join_state recovers to steady before TTL expires" do
        listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))
        listener.on_statistics_emitted(stats_event(join_state: "steady"))
        expect(listener.healthy?).to be(true)
      end
    end
  end

  describe "#status_body" do
    it "includes the stability_ttl_exceeded key" do
      body = listener.send(:status_body)
      expect(body[:errors]).to have_key(:stability_ttl_exceeded)
    end

    it "reports false when no subscription group is stuck" do
      body = listener.send(:status_body)
      expect(body[:errors][:stability_ttl_exceeded]).to be(false)
    end

    it "reports true when a subscription group exceeds the TTL" do
      fast_listener = described_class.new(stability_ttl: 0)
      fast_listener.on_statistics_emitted(stats_event(join_state: "wait-join"))
      body = fast_listener.send(:status_body)
      expect(body[:errors][:stability_ttl_exceeded]).to be(true)
    end

    it "preserves the base envelope fields from BaseListener#status_body" do
      body = listener.send(:status_body)
      expect(body).to include(:status, :timestamp, :port, :process_id, :errors)
    end
  end

  describe "default stability_ttl derivation" do
    let(:stability_ttl) { listener.send(:stability_ttl) }

    def sg_with(max_poll_interval)
      instance_double(
        Karafka::Routing::SubscriptionGroup,
        kafka: { "max.poll.interval.ms": max_poll_interval }
      )
    end

    context "when stability_ttl is not provided" do
      it "is not resolved at initialize time" do
        expect(listener.instance_variable_get(:@stability_ttl)).to be_nil
      end

      context "when subscription groups are available" do
        before do
          allow(Karafka::App).to receive(:subscription_groups).and_return(
            cg1: [sg_with(300_000), sg_with(900_000)],
            cg2: [sg_with(600_000)]
          )
        end

        it "derives the default as the max max.poll.interval.ms across all groups times 2" do
          expect(stability_ttl).to eq(900_000 * 2)
        end

        it "does not fall back to the root kafka config" do
          expect(Karafka::Setup::DefaultsInjector).not_to receive(:consumer)
          stability_ttl
        end
      end

      context "when no subscription groups are available" do
        before { allow(Karafka::App).to receive(:subscription_groups).and_return({}) }

        it "falls back to the root config max.poll.interval.ms times 2 (librdkafka default)" do
          expect(stability_ttl).to eq(300_000 * 2)
        end

        context "when Karafka::App.config.kafka explicitly sets max.poll.interval.ms" do
          before do
            allow(Karafka::App.config).to receive(:kafka).and_return(
              "max.poll.interval.ms": 900_000
            )
          end

          it "uses the configured value times 2" do
            expect(stability_ttl).to eq(900_000 * 2)
          end
        end

        context "when DefaultsInjector fills in the librdkafka default" do
          # An empty kafka config gets max.poll.interval.ms=300_000 injected by DefaultsInjector
          # which the listener then doubles.
          before { allow(Karafka::App.config).to receive(:kafka).and_return({}) }

          it "results in 600_000 ms (5 min * 2) when the user hasn't set the key" do
            expect(stability_ttl).to eq(600_000)
          end
        end
      end
    end

    context "when stability_ttl is explicitly provided" do
      subject(:listener) { described_class.new(stability_ttl: 12_345) }

      it "uses the provided value verbatim and does not derive" do
        expect(stability_ttl).to eq(12_345)
      end

      it "does not consult routing or DefaultsInjector for the derivation path" do
        expect(Karafka::App).not_to receive(:subscription_groups)
        expect(Karafka::Setup::DefaultsInjector).not_to receive(:consumer)
        stability_ttl
      end
    end
  end
end
