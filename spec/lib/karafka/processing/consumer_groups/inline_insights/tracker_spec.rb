# frozen_string_literal: true

RSpec.describe_current do
  let(:tracker) { described_class.instance }
  let(:group_id) { group.id }
  let(:statistics_name) { "stat_name" }
  let(:statistics) { { "name" => statistics_name } }
  let(:partition) { 5 }
  let(:group) { build(:routing_consumer_group) }
  let(:topic) { build(:routing_topic, name: "topic_name", group: group) }
  let(:statistics) do
    {
      "name" => statistics_name,
      "topics" => {
        "topic_name" => {
          "partitions" => {
            "5" => {
              "some_key" => "some_value",
              "fetch_state" => "active"
            }
          }
        }
      }
    }
  end

  describe "#find" do
    subject(:result) { tracker.find(topic, partition) }

    context "when statistics exist" do
      before { tracker.add(group_id, statistics) }

      it "returns the statistics for the given topic and partition" do
        expect(result).to eq("some_key" => "some_value", "fetch_state" => "active")
      end
    end

    context "when statistics exist but for not active partition" do
      before do
        statistics["topics"]["topic_name"]["partitions"]["5"]["fetch_state"] = "none"
        tracker.add(group_id, statistics)
      end

      it "returns nothing" do
        expect(result).to eq({})
      end
    end

    context "when statistics do not exist" do
      it "returns an empty hash" do
        expect(result).to eq({})
      end
    end
  end

  describe "#add" do
    subject(:result) { tracker.add(group_id, statistics) }

    it "adds the statistics to the tracker" do
      expect { result }.to change { tracker.find(topic, partition) }.from({})
    end

    context "when tracked statistics expire" do
      let(:now) { [0] }
      let(:next_statistics) do
        {
          "topics" => {
            "topic_name" => {
              "partitions" => { "6" => { "some_key" => "other_value", "fetch_state" => "active" } }
            }
          }
        }
      end

      before do
        allow(tracker).to receive(:monotonic_now) { now.first }
        tracker.add(group_id, statistics)
        now[0] = 5 * 60 * 1_000 + 1
        tracker.add(group_id, next_statistics)
      end

      it "evicts them on the next add" do
        expect(tracker.find(topic, partition)).to eq({})
      end

      it "keeps the statistics from the next add" do
        expect(tracker.find(topic, 6)).to eq("some_key" => "other_value", "fetch_state" => "active")
      end
    end

    context "when find runs while statistics are being added" do
      let(:next_details) { { "some_key" => "next_value", "fetch_state" => "active" } }
      let(:other_details) { { "fetch_state" => "active" } }
      let(:next_statistics) do
        {
          "topics" => {
            "topic_name" => {
              "partitions" => { "5" => next_details, "6" => other_details }
            }
          }
        }
      end
      let(:found_during_add) { [] }

      before do
        tracker.add(group_id, statistics)

        allow(other_details).to receive(:fetch).and_wrap_original do |original, *args|
          found_during_add << tracker.find(topic, partition)
          original.call(*args)
        end
      end

      it "reads the previous complete snapshot" do
        tracker.add(group_id, next_statistics)

        expect(found_during_add).to eq([{ "some_key" => "some_value", "fetch_state" => "active" }])
      end

      it "reads the new snapshot once the add is done" do
        tracker.add(group_id, next_statistics)

        expect(tracker.find(topic, partition)).to eq(next_details)
      end
    end
  end

  describe ".exists?" do
    subject(:result) { described_class.exists?(topic, partition) }

    context "when statistics exist" do
      before { tracker.add(group_id, statistics) }

      it { expect(result).to be(true) }
    end

    context "when statistics do not exist" do
      before { tracker.clear }

      it { expect(result).to be(false) }
    end
  end

  describe "#clear" do
    before { tracker.add(group_id, statistics) }

    it "removes all the statistics" do
      expect { tracker.clear }.to change { tracker.find(topic, partition) }.to({})
    end
  end
end
