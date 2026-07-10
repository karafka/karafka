# frozen_string_literal: true

require "karafka/instrumentation/vendors/kubernetes/readiness_listener"

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:polled_groups) { listener.instance_variable_get(:@polled_groups) }

  # A `connection.listener.fetch_loop` event carries the subscription group that polled.
  def fetch_loop_event(group_id)
    sg = instance_double(Karafka::Routing::SubscriptionGroup, id: group_id)
    { subscription_group: sg }
  end

  # Stub the active subscription group set the gate compares against.
  # `Karafka::App.subscription_groups` returns { consumer_group => [subscription_group, ...] }.
  def stub_active_groups(*group_ids)
    sgs = group_ids.map { |id| instance_double(Karafka::Routing::SubscriptionGroup, id: id) }
    cg = instance_double(Karafka::Routing::ConsumerGroup)
    allow(Karafka::App).to receive(:subscription_groups).and_return({ cg => sgs })
  end

  describe "events mapping" do
    it { expect(NotificationsChecker.valid?(listener)).to be(true) }
  end

  describe "#healthy? with a known active group set" do
    before { stub_active_groups("sg_a", "sg_b") }

    it "is not ready before any group has polled" do
      expect(listener.healthy?).to be(false)
    end

    it "is not ready when only some active groups have polled" do
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
      expect(listener.healthy?).to be(false)
    end

    it "is ready once every active group has polled" do
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_b"))
      expect(listener.healthy?).to be(true)
    end

    it "latches: an extra/unknown group tick after the gate opens keeps it ready" do
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_b"))
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_c"))
      expect(listener.healthy?).to be(true)
    end

    it "ignores a fetch_loop event without a subscription group" do
      listener.on_connection_listener_fetch_loop({})
      expect(polled_groups).to be_empty
      expect(listener.healthy?).to be(false)
    end
  end

  describe "#healthy? the all-groups-polled latch is monotonic" do
    before { stub_active_groups("sg_a") }

    it "stays ready if the poll tracking set is later emptied" do
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
      expect(listener.healthy?).to be(true)

      # The latch only ever goes false -> true, so emptying the tracked set must not flip it back.
      polled_groups.clear
      expect(listener.healthy?).to be(true)
    end
  end

  describe "#healthy? while the process is shutting down or quieting" do
    before { stub_active_groups("sg_a") }

    # Each of these states makes Karafka::App.done? true.
    %i[quieting? quiet? stopping? stopped? terminated?].each do |state|
      context "when Karafka::App is #{state.to_s.delete("?")}" do
        before do
          listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
          allow(Karafka::App).to receive(:done?).and_return(true)
        end

        it "reports not-ready even though all groups polled (so k8s can drain it)" do
          expect(listener.healthy?).to be(false)
        end
      end
    end

    it "becomes ready again only while not draining" do
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
      expect(listener.healthy?).to be(true)

      allow(Karafka::App).to receive(:done?).and_return(true)
      expect(listener.healthy?).to be(false)
    end
  end

  describe "#healthy? fallback when the active set can't be determined" do
    context "when subscription_groups is empty" do
      before { allow(Karafka::App).to receive(:subscription_groups).and_return({}) }

      it "falls back to 'at least one group polled' so a pod is never wedged un-ready" do
        expect(listener.healthy?).to be(false)
        listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
        expect(listener.healthy?).to be(true)
      end
    end

    context "when subscription_groups raises" do
      before { allow(Karafka::App).to receive(:subscription_groups).and_raise(StandardError) }

      it "falls back to 'at least one group polled'" do
        expect(listener.healthy?).to be(false)
        listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
        expect(listener.healthy?).to be(true)
      end
    end
  end

  describe "#status_body" do
    before { stub_active_groups("sg_a", "sg_b") }

    it "preserves the base envelope fields from BaseListener#status_body" do
      body = listener.send(:status_body)
      expect(body).to include(:status, :timestamp, :port, :process_id)
    end

    it "reports the readiness fields before any group has polled" do
      body = listener.send(:status_body)
      expect(body).to include(
        ready: false,
        polled_subscription_groups: 0,
        expected_subscription_groups: 2
      )
    end

    it "reports the readiness fields once every group has polled" do
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_b"))
      body = listener.send(:status_body)
      expect(body).to include(
        ready: true,
        polled_subscription_groups: 2,
        expected_subscription_groups: 2
      )
    end

    it "reports the base status as unhealthy until ready and healthy once ready" do
      expect(listener.send(:status_body)[:status]).to eq("unhealthy")
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_b"))
      expect(listener.send(:status_body)[:status]).to eq("healthy")
    end

    it "derives status and the ready field from a single snapshot (they always agree)" do
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a"))
      listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_b"))
      body = listener.send(:status_body)
      expect(body[:ready]).to be(body[:status] == "healthy")
    end

    it "does not leak the per-request health snapshot after the call" do
      listener.send(:status_body)
      expect(listener.instance_variable_get(:@health_snapshot)).to be_nil
    end
  end

  describe "thread safety (no-deadlock smoke check)" do
    before { stub_active_groups("sg_a") }

    it "does not deadlock or raise when polled and probed concurrently" do
      threads = [
        Thread.new { 500.times { listener.on_connection_listener_fetch_loop(fetch_loop_event("sg_a")) } },
        Thread.new { 500.times { listener.healthy? } }
      ]
      expect { threads.each(&:join) }.not_to raise_error
      expect(listener.healthy?).to be(true)
    end
  end
end
