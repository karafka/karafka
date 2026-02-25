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
  let(:tracker) { described_class.new }
  let(:current_time) { Time.now.to_i }
  let(:today_date) { Time.at(current_time).utc.to_date.to_s }

  before do
    # Stubbing Time.now to have consistent test results
    allow(Time).to receive(:now).and_return(Time.at(current_time))
  end

  describe "#initialize" do
    it "initializes with an empty daily hash and current time" do
      expect(tracker.to_h[:daily]).to eq({})
      expect(tracker.to_h[:state]).to eq("fresh")
    end
  end

  describe "#today=" do
    it "sets the count for the current day" do
      tracker.today = 5
      expect(tracker.to_h[:daily][today_date]).to eq(5)
    end
  end

  describe "#future" do
    let(:message) do
      instance_double(
        Karafka::Messages::Message,
        headers: { "schedule_target_epoch" => epoch }
      )
    end

    context "when tracking a message for today" do
      let(:epoch) { current_time }

      it "increases the count for the current day" do
        tracker.today = 5
        tracker.future(message)
        expect(tracker.to_h[:daily][today_date]).to eq(6)
      end
    end

    context "when tracking a message for a future day" do
      let(:future_time) { Time.now.to_i + 86_400 } # One day in the future
      let(:future_date) { Time.at(future_time).utc.to_date.to_s }
      let(:epoch) { future_time }

      it "increases the count for the future day" do
        tracker.future(message)
        expect(tracker.to_h[:daily][future_date]).to eq(1)
      end
    end

    context "when tracking a message for a past day" do
      let(:past_time) { Time.now.to_i - 86_400 } # One day in the past
      let(:past_date) { Time.at(past_time).utc.to_date.to_s }
      let(:epoch) { past_time }

      it "increases the count for the past day" do
        tracker.future(message)
        expect(tracker.to_h[:daily][past_date]).to eq(1)
      end
    end
  end

  describe "#epoch_to_date" do
    it "converts an epoch to the correct date string" do
      epoch = Time.now.to_i
      date_string = Time.at(epoch).utc.to_date.to_s
      expect(tracker.send(:epoch_to_date, epoch)).to eq(date_string)
    end
  end

  describe "#offsets" do
    let(:message) do
      instance_double(
        Karafka::Messages::Message,
        offset: message_offset
      )
    end

    context "when tracking the first message" do
      let(:message_offset) { 100 }

      before { tracker.offsets(message) }

      it { expect(tracker.to_h[:offsets][:low]).to eq(100) }
      it { expect(tracker.to_h[:offsets][:high]).to eq(100) }
    end

    context "when tracking subsequent messages" do
      let(:first_message) do
        instance_double(
          Karafka::Messages::Message,
          offset: 50
        )
      end
      let(:second_message) do
        instance_double(
          Karafka::Messages::Message,
          offset: 150
        )
      end

      before do
        tracker.offsets(first_message)
        tracker.offsets(second_message)
      end

      it { expect(tracker.to_h[:offsets][:low]).to eq(50) }
      it { expect(tracker.to_h[:offsets][:high]).to eq(150) }
    end

    context "when tracking messages with decreasing offsets" do
      let(:first_message) do
        instance_double(
          Karafka::Messages::Message,
          offset: 200
        )
      end
      let(:second_message) do
        instance_double(
          Karafka::Messages::Message,
          offset: 100
        )
      end

      before do
        tracker.offsets(first_message)
        tracker.offsets(second_message)
      end

      it { expect(tracker.to_h[:offsets][:low]).to eq(200) }
      it { expect(tracker.to_h[:offsets][:high]).to eq(100) }
    end
  end

  describe "#to_h" do
    it { expect(tracker.to_h).to be_frozen }
    it { expect(tracker.to_h).to be_a(Hash) }
    it { expect(tracker.to_h[:offsets]).to be_a(Hash) }
    it { expect(tracker.to_h[:offsets][:low]).to eq(-1) }
    it { expect(tracker.to_h[:offsets][:high]).to eq(-1) }
    it { expect(tracker.to_h[:daily]).to be_a(Hash) }
    it { expect(tracker.to_h[:started_at]).to eq(current_time) }
    it { expect(tracker.to_h[:reloads]).to eq(0) }

    context "with updated state" do
      before { tracker.state = "running" }

      it { expect(tracker.to_h[:state]).to eq("running") }
    end

    context "when we set daily data" do
      before { tracker.today = 10 }

      it { expect(tracker.to_h[:daily][today_date]).to eq(10) }
    end

    context "when we track offsets" do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          offset: 42
        )
      end

      before { tracker.offsets(message) }

      it { expect(tracker.to_h[:offsets][:low]).to eq(42) }
      it { expect(tracker.to_h[:offsets][:high]).to eq(42) }
    end

    context "when we encounter future messages" do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { "schedule_target_epoch" => current_time }
        )
      end

      before { tracker.future(message) }

      it { expect(tracker.to_h[:daily][today_date]).to eq(1) }
    end

    context "when we update the state" do
      before { tracker.state = "active" }

      it { expect(tracker.to_h[:state]).to eq("active") }
    end
  end
end
