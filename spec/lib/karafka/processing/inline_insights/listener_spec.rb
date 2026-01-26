# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:tracker) { Karafka::Processing::InlineInsights::Tracker.instance }
  let(:consumer_group_id) { rand.to_s }
  let(:statistics) { { rand => rand } }
  let(:event) { { consumer_group_id: consumer_group_id, statistics: statistics } }

  describe "#on_statistics_emitted" do
    before { allow(tracker).to receive(:add) }

    it "expect to use tracker and give it consumer group and statistics" do
      listener.on_statistics_emitted(event)

      expect(tracker).to have_received(:add).with(consumer_group_id, statistics)
    end
  end

  describe "events mapping" do
    it { expect(NotificationsChecker.valid?(listener)).to be(true) }
  end
end
