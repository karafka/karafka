# frozen_string_literal: true

RSpec.describe_current do
  subject(:group) { described_class.new(0, topics) }

  let(:topic) { build(:routing_topic, kafka: { "bootstrap.servers": "kafka://kafka:9092" }) }
  let(:topics) { [topic] }

  describe "#id" do
    it do
      expect(group.id)
        .to eq("#{topic.consumer_group.id}_#{topic.subscription_group_details.fetch(:name)}_0")
    end
  end

  describe "#to_s" do
    it { expect(group.to_s).to eq(group.id) }
  end

  describe "#max_messages" do
    it { expect(group.max_messages).to eq(topic.max_messages) }
  end

  describe "#max_wait_time" do
    it { expect(group.max_wait_time).to eq(topic.max_wait_time) }
  end

  describe "#topics" do
    it { expect(group.topics).to eq([topic]) }
  end

  describe "#consumer_group" do
    it { expect(group.consumer_group).to eq(topic.consumer_group) }
  end

  describe "#subscriptions" do
    it { expect(group.subscriptions).to eq([topic.name]) }

    context "when there are inactive topics in given group" do
      let(:topic2) { build(:routing_topic).tap { |top| top.active(false) } }

      before { topics << topic2 }

      it "expect not to include inactive topics" do
        expect(group.subscriptions).to eq([topic.name])
      end
    end
  end

  describe "#consumer_group_id" do
    it { expect(group.consumer_group_id).to eq(topic.consumer_group.id) }
  end

  describe "#kafka" do
    it { expect(group.kafka[:"client.id"]).to eq(Karafka::App.config.client_id) }
    it { expect(group.kafka[:"auto.offset.reset"]).to eq("earliest") }
    it { expect(group.kafka[:"enable.auto.offset.store"]).to be(false) }
    it { expect(group.kafka[:"bootstrap.servers"]).to eq(topic.kafka[:"bootstrap.servers"]) }

    context "when with group.instance.id" do
      let(:topic) do
        build(
          :routing_topic,
          kafka: {
            "bootstrap.servers": "kafka://kafka:9092",
            "group.instance.id": "test"
          }
        )
      end

      context "when not operating in a swarm node" do
        it "expect group.instance.id not to use node.id" do
          expect(group.kafka[:"group.instance.id"]).to eq("test_0")
        end
      end

      context "when operating in a swarm node" do
        before { Karafka::App.config.swarm.node = build(:swarm_node, id: 3) }

        after { Karafka::App.config.swarm.node = false }

        it "expect group.instance.id to use node.id" do
          expect(group.kafka[:"group.instance.id"]).to eq("test_3_0")
        end
      end
    end

    context "when cooperative-sticky mode when client.id was configured directly" do
      let(:time_now) { 1_721_306_083.6994138 }
      let(:hex) { "5708a73b9df92ee41059ab3ce6a06020" }
      let(:client_id) { group.kafka[:"client.id"] }

      let(:topic) do
        build(
          :routing_topic,
          kafka: {
            "bootstrap.servers": "kafka://kafka:9092",
            "partition.assignment.strategy": "cooperative-sticky",
            "client.id": "test"
          }
        )
      end

      before do
        allow(Time).to receive(:now).and_return(time_now)
        allow(SecureRandom).to receive(:hex).and_return(hex)
      end

      it "expect to not to use the dynamic format" do
        expect(client_id).to eq("test")
      end
    end

    context "when client.id is not set but rebalance is not cooperative-sticky" do
      let(:client_id) { group.kafka[:"client.id"] }

      let(:topic) do
        build(
          :routing_topic,
          kafka: {
            "bootstrap.servers": "kafka://kafka:9092",
            "partition.assignment.strategy": "anything-else"
          }
        )
      end

      it "expect to use the dynamic format that mitigates librdkafka rebalance bug" do
        expect(client_id).to eq(Karafka::App.config.client_id)
      end
    end
  end

  describe "#active?" do
    context "when there are no topics in the subscription group" do
      it { expect(group.active?).to be(true) }
    end

    context "when our subscription group name is in server subscription groups" do
      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:subscription_groups, topic.subscription_group_details.fetch(:name))
      end

      it { expect(group.active?).to be(true) }
    end

    context "when our subscription group name is not in server subscription groups" do
      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:subscription_groups, "na")
      end

      it { expect(group.active?).to be(false) }
    end
  end

  describe "#refresh" do
    context "when node reference is changed" do
      let(:node) { build(:swarm_node, id: 2) }
      let(:pre_id) { group.kafka[:"group.instance.id"] }
      let(:post_id) { group.kafka[:"group.instance.id"] }

      let(:topic) do
        build(
          :routing_topic,
          kafka: {
            "bootstrap.servers": "kafka://kafka:9092",
            "group.instance.id": "test"
          }
        )
      end

      before do
        pre_id
        Karafka::App.config.swarm.node = node
        group.refresh
        post_id
      end

      after { Karafka::App.config.swarm.node = false }

      it "expect to refresh the group.instance.id" do
        expect(pre_id).to eq("test_0")
        expect(post_id).to eq("test_2_0")
      end
    end
  end
end
