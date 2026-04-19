# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(topic, partition, pause_tracker) }

  let(:topic) { build(:routing_topic) }
  let(:partition) { 0 }
  let(:pause_tracker) { build(:time_trackers_pause) }
  let(:message) { build(:messages_message) }

  describe "#last_polled_at" do
    it { expect(coordinator.last_polled_at).to be > 0 }
  end

  describe "#pause_tracker" do
    it { expect(coordinator.pause_tracker).to eq(pause_tracker) }
  end

  describe "#start" do
    before { coordinator.start([message]) }

    it { expect(coordinator.success?).to be(true) }
    it { expect(coordinator.revoked?).to be(false) }
    it { expect(coordinator.manual_pause?).to be(false) }
    it { expect(coordinator.manual_seek?).to be(false) }

    context "when previous coordinator usage had a manual pause" do
      before do
        pause_tracker.pause
        coordinator.manual_pause
        coordinator.start([message])
      end

      it { expect(coordinator.success?).to be(true) }
      it { expect(coordinator.revoked?).to be(false) }
      it { expect(coordinator.manual_pause?).to be(false) }
    end

    context "when previous coordinator usage had a manual seek" do
      before do
        coordinator.manual_seek
        coordinator.start([message])
      end

      it { expect(coordinator.success?).to be(true) }
      it { expect(coordinator.revoked?).to be(false) }
      it { expect(coordinator.manual_seek?).to be(false) }
    end
  end

  describe "#increment" do
    before { coordinator.increment(:consume) }

    it { expect(coordinator.success?).to be(false) }
    it { expect(coordinator.revoked?).to be(false) }
  end

  describe "#decrement" do
    context "when we would go below zero jobs" do
      it "expect to raise error" do
        expected_error = Karafka::Errors::InvalidCoordinatorStateError
        expect { coordinator.decrement(:consume) }.to raise_error(expected_error)
      end
    end

    context "when decrementing from regular jobs count to zero" do
      before do
        coordinator.increment(:consume)
        coordinator.decrement(:consume)
      end

      it { expect(coordinator.success?).to be(true) }
      it { expect(coordinator.revoked?).to be(false) }
    end

    context "when decrementing from regular jobs count not to zero" do
      before do
        coordinator.increment(:consume)
        coordinator.increment(:consume)
        coordinator.decrement(:consume)
      end

      it { expect(coordinator.success?).to be(false) }
      it { expect(coordinator.revoked?).to be(false) }
    end
  end

  describe "#synchronize" do
    it "expect to run provided code" do
      value = 0
      coordinator.synchronize { value += 1 }
      expect(value).to eq(1)
    end

    context "when already in synchronize" do
      it "expect to run provided code" do
        value = 0
        coordinator.synchronize { coordinator.synchronize { value += 1 } }
        expect(value).to eq(1)
      end
    end
  end

  describe "#success?" do
    context "when there were no jobs" do
      it { expect(coordinator.success?).to be(true) }
    end

    context "when there is a job running" do
      before { coordinator.increment(:consume) }

      it { expect(coordinator.success?).to be(false) }
    end

    context "when there are no jobs running and all the finished are success" do
      before { coordinator.success!(0) }

      it { expect(coordinator.success?).to be(true) }
    end

    context "when there are jobs running and all the finished are success" do
      before do
        coordinator.success!(0)
        coordinator.increment(:consume)
      end

      it { expect(coordinator.success?).to be(false) }
    end

    context "when there are no jobs running and not all the jobs finished with success" do
      before do
        coordinator.success!(0)
        coordinator.failure!(1, StandardError.new)
      end

      it { expect(coordinator.success?).to be(false) }
      it { expect(coordinator.failure?).to be(true) }
    end
  end

  describe "#revoke and #revoked?" do
    before { coordinator.revoke }

    it { expect(coordinator.revoked?).to be(true) }
  end

  describe "#marked?" do
    context "when having newly created coordinator" do
      it { expect(coordinator.marked?).to be(false) }
    end

    context "when any new seek offset was assigned" do
      before { coordinator.seek_offset = 0 }

      it { expect(coordinator.marked?).to be(true) }
    end
  end

  describe "#eofed?" do
    context "when having newly created coordinator" do
      it { expect(coordinator.eofed?).to be(false) }
    end

    context "when was eofed" do
      before { coordinator.eofed = true }

      it { expect(coordinator.eofed?).to be(true) }
    end
  end

  describe "#manual_pause and manual_pause?" do
    context "when there is no pause" do
      it { expect(coordinator.manual_pause?).to be(false) }
    end

    context "when there is a system pause" do
      before { pause_tracker.pause }

      it { expect(coordinator.manual_pause?).to be(false) }
    end

    context "when there is a manual pause" do
      before do
        pause_tracker.pause
        coordinator.manual_pause
      end

      it { expect(coordinator.manual_pause?).to be(true) }
    end
  end

  describe "#manual_seek and manual_seek?" do
    context "when there is no seek" do
      it { expect(coordinator.manual_seek?).to be(false) }
    end

    context "when there is a manual seek" do
      before { coordinator.manual_seek }

      it { expect(coordinator.manual_seek?).to be(true) }
    end
  end
end
