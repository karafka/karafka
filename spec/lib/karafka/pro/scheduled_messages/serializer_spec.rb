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
  let(:tracker) { Karafka::Pro::ScheduledMessages::Tracker.new }
  let(:serializer) { described_class.new }
  let(:float_now) { rand }
  let(:current_time) { Time.now.to_i }

  before do
    allow(serializer).to receive(:float_now).and_return(float_now)
    allow(Time).to receive(:now).and_return(Time.at(current_time))
  end

  describe "#state" do
    it "merges tracker data with schema version and timestamp, then serializes and compresses" do
      expected_data = {
        schema_version: Karafka::Pro::ScheduledMessages::STATES_SCHEMA_VERSION,
        dispatched_at: float_now
      }.merge(tracker.to_h).to_json

      compressed_data = Zlib::Deflate.deflate(expected_data)

      expect(serializer.state(tracker)).to eq(compressed_data)
    end

    context "with fresh tracker" do
      it { expect(serializer.state(tracker)).to be_a(String) }

      it "includes default tracker data in the serialized output" do
        result = serializer.state(tracker)
        decompressed = Zlib::Inflate.inflate(result)
        parsed = JSON.parse(decompressed)

        expect(parsed["state"]).to eq("fresh")
        expect(parsed["offsets"]).to eq({ "low" => -1, "high" => -1 })
        expect(parsed["daily"]).to eq({})
        expect(parsed["started_at"]).to eq(current_time)
        expect(parsed["reloads"]).to eq(0)
      end
    end

    context "with configured tracker" do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          offset: 100,
          headers: { "schedule_target_epoch" => current_time }
        )
      end

      before do
        tracker.state = "active"
        tracker.today = 10
        tracker.offsets(message)
        tracker.future(message)
      end

      it "preserves all configured data in serialization" do
        result = serializer.state(tracker)
        decompressed = Zlib::Inflate.inflate(result)
        parsed = JSON.parse(decompressed)

        expect(parsed["state"]).to eq("active")
        expect(parsed["offsets"]).to eq({ "low" => 100, "high" => 100 })
        expect(parsed["daily"][Time.at(current_time).utc.to_date.to_s]).to eq(11)
        expect(parsed["started_at"]).to eq(current_time)
        expect(parsed["reloads"]).to eq(0)
      end
    end

    context "with multiple days tracked" do
      let(:today_message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { "schedule_target_epoch" => current_time }
        )
      end
      let(:future_message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { "schedule_target_epoch" => current_time + 86_400 }
        )
      end

      before do
        tracker.today = 5
        tracker.future(today_message)
        tracker.future(future_message)
      end

      it "includes multiple days in daily tracking" do
        result = serializer.state(tracker)
        decompressed = Zlib::Inflate.inflate(result)
        parsed = JSON.parse(decompressed)

        today_date = Time.at(current_time).utc.to_date.to_s
        future_date = Time.at(current_time + 86_400).utc.to_date.to_s

        expect(parsed["daily"][today_date]).to eq(6) # 5 + 1
        expect(parsed["daily"][future_date]).to eq(1)
      end
    end
  end
end
