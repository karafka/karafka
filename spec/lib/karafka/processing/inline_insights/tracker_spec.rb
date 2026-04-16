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
  end
end
