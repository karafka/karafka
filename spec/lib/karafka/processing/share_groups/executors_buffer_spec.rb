# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new(client, subscription_group) }

  let(:client) { instance_double(Karafka::Connection::ShareGroups::Client) }
  let(:topic) { build(:routing_share_topic) }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(topic, 0) }
  let(:topic_name) { "topic_name1" }
  let(:subscription_group) { groups.first.subscription_groups.first }

  let(:fetched_executor) { buffer.find_or_create(topic_name, 0, 0, coordinator) }

  let(:groups) do
    Karafka::Routing::Builder.new.draw do
      share_group :group_name1 do
        topic :topic_name1 do
          consumer Class.new(Karafka::ShareConsumer)
        end
      end
    end
  end

  describe "#find_or_create" do
    context "when the executor is not in the buffer" do
      it { expect(fetched_executor.group_id).to eq(subscription_group.id) }

      it "expect to create a new one" do
        expect(fetched_executor).to be_a(Karafka::Processing::ShareGroups::Executor)
      end
    end

    context "when executor is in a buffer" do
      let(:existing_executor) { buffer.find_or_create(topic_name, 0, 0, coordinator) }

      before { existing_executor }

      it "expect to re-use existing one" do
        expect(fetched_executor).to eq(existing_executor)
      end
    end

    context "when asking for another partition or parallel key" do
      before { fetched_executor }

      it "expect to create separate executors" do
        other_partition = buffer.find_or_create(topic_name, 1, 0, coordinator)
        other_key = buffer.find_or_create(topic_name, 0, 1, coordinator)

        expect([fetched_executor, other_partition, other_key].uniq.size).to eq(3)
      end
    end
  end

  describe "#each" do
    context "when there are no executors" do
      it "expect not to yield anything" do
        expect { |block| buffer.each(&block) }.not_to yield_control
      end
    end

    context "when there are executors" do
      before { fetched_executor }

      it "expect to yield with the executor" do
        expect { |block| buffer.each(&block) }.to yield_with_args(fetched_executor)
      end
    end
  end

  describe "#clear" do
    let(:pre_cleaned_executor) { buffer.find_or_create(topic_name, 0, 0, coordinator) }

    before do
      pre_cleaned_executor
      buffer.clear
    end

    it "expect to rebuild after clearing as clearing should empty the buffer" do
      expect(fetched_executor).not_to eq(pre_cleaned_executor)
    end
  end
end
