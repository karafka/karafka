# frozen_string_literal: true

RSpec.describe_current do
  let(:name) { generate_topic_name }
  let(:topics) { described_class.cluster_info.topics.map { |tp| tp[:topic_name] } }

  describe "#create_topic" do
    it "delegates to Admin::Topics#create" do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:create).with(name, 2, 1, {})
      described_class.create_topic(name, 2, 1)
    end

    it "passes through topic_config parameter" do
      config = { "cleanup.policy" => "compact" }
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:create).with(name, 2, 1, config)
      described_class.create_topic(name, 2, 1, config)
    end
  end

  describe "#delete_topic" do
    it "delegates to Admin::Topics#delete" do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:delete).with(name)
      described_class.delete_topic(name)
    end
  end

  describe "#read_topic" do
    let(:partition) { 0 }
    let(:count) { 1 }
    let(:offset) { -1 }
    let(:settings) { {} }

    it "delegates to Admin::Topics#read with all parameters" do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:read).with(name, partition, count, offset, settings)
      described_class.read_topic(name, partition, count, offset, settings)
    end

    it "delegates to Admin::Topics#read with default parameters" do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:read).with(name, partition, count, -1, {})
      described_class.read_topic(name, partition, count)
    end
  end

  describe "#create_partitions" do
    let(:partitions) { 7 }

    it "delegates to Admin::Topics#create_partitions" do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:create_partitions).with(name, partitions)
      described_class.create_partitions(name, partitions)
    end
  end

  describe "#topic_info" do
    it "delegates to Admin::Topics#info" do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:info).with(name)
      described_class.topic_info(name)
    end
  end

  describe "#read_watermark_offsets" do
    let(:partition) { 0 }
    let(:topics_with_partitions) { { name => [0, 1] } }

    context "when called with topic and partition" do
      it "delegates to Admin::Topics#read_watermark_offsets" do
        expect_any_instance_of(Karafka::Admin::Topics)
          .to receive(:read_watermark_offsets).with(name, partition)
        described_class.read_watermark_offsets(name, partition)
      end
    end

    context "when called with topics hash" do
      it "delegates to Admin::Topics#read_watermark_offsets" do
        expect_any_instance_of(Karafka::Admin::Topics)
          .to receive(:read_watermark_offsets).with(topics_with_partitions, nil)
        described_class.read_watermark_offsets(topics_with_partitions)
      end
    end
  end

  describe "#read_partition_offsets" do
    let(:specs) { { name => [{ partition: 0, offset: :earliest }] } }

    it "delegates to Admin::Topics#read_partition_offsets with default isolation_level" do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:read_partition_offsets).with(specs, isolation_level: nil)
      described_class.read_partition_offsets(specs)
    end

    it "delegates to Admin::Topics#read_partition_offsets with custom isolation_level" do
      level = Karafka::Admin::IsolationLevels::READ_COMMITTED
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:read_partition_offsets).with(specs, isolation_level: level)
      described_class.read_partition_offsets(specs, isolation_level: level)
    end
  end

  # More specs in the integrations
  describe "#seek_consumer_group" do
    let(:group_id) { SecureRandom.uuid }
    let(:map) { { "topic" => { 0 => 10 } } }

    it "delegates to ConsumerGroups#seek" do
      expect_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:seek).with(group_id, map)
      described_class.seek_consumer_group(group_id, map)
    end
  end

  describe "#copy_consumer_group" do
    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    it "delegates to ConsumerGroups#copy" do
      expect_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:copy).with(previous_name, new_name, topics)
      described_class.copy_consumer_group(previous_name, new_name, topics)
    end
  end

  describe "#rename_consumer_group" do
    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    context "when delete_previous is not specified" do
      it "delegates to ConsumerGroups#rename with default delete_previous" do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:rename)
          .with(previous_name, new_name, topics, delete_previous: true)
        described_class.rename_consumer_group(previous_name, new_name, topics)
      end
    end

    context "when delete_previous is specified" do
      it "delegates to ConsumerGroups#rename with specified delete_previous" do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:rename)
          .with(previous_name, new_name, topics, delete_previous: false)
        described_class.rename_consumer_group(
          previous_name,
          new_name,
          topics,
          delete_previous: false
        )
      end
    end
  end

  describe "#delete_consumer_group" do
    let(:group_id) { SecureRandom.uuid }

    it "delegates to ConsumerGroups#delete" do
      expect_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:delete).with(group_id)
      described_class.delete_consumer_group(group_id)
    end
  end

  describe "#trigger_rebalance" do
    let(:group_id) { SecureRandom.uuid }

    it "delegates to ConsumerGroups#trigger_rebalance" do
      expect_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:trigger_rebalance).with(group_id)
      described_class.trigger_rebalance(group_id)
    end
  end

  describe "#read_lags_with_offsets" do
    let(:groups_with_topics) { { "test_group" => ["test_topic"] } }

    context "when active_topics_only is not specified" do
      it "delegates to ConsumerGroups#read_lags_with_offsets with default active_topics_only" do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:read_lags_with_offsets)
          .with(groups_with_topics, active_topics_only: true)
        described_class.read_lags_with_offsets(groups_with_topics)
      end
    end

    context "when active_topics_only is specified" do
      it "delegates to ConsumerGroups#read_lags_with_offsets with specified active_topics_only" do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:read_lags_with_offsets)
          .with(groups_with_topics, active_topics_only: false)
        described_class.read_lags_with_offsets(groups_with_topics, active_topics_only: false)
      end
    end

    context "when groups_with_topics is not specified" do
      it "delegates to ConsumerGroups#read_lags_with_offsets with empty hash" do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:read_lags_with_offsets)
          .with({}, active_topics_only: true)
        described_class.read_lags_with_offsets
      end
    end
  end

  describe "#with_consumer" do
    context "when operating on an external client" do
      subject(:admin) { described_class.new(external_client: external_client) }

      let(:external_client) { instance_double(Rdkafka::Consumer) }

      it "yields a proxy wrapping the external client" do
        admin.with_consumer do |proxy|
          expect(proxy).to be_a(Karafka::Connection::Proxy)
          expect(proxy.wrapped).to eq(external_client)
        end
      end

      it "does not wrap an already proxied external client with another proxy level" do
        proxied = Karafka::Connection::Proxy.new(external_client)

        described_class.new(external_client: proxied).with_consumer do |proxy|
          expect(proxy.wrapped).to eq(external_client)
        end
      end

      it "does not manage the external client lifecycle" do
        # Verifying double raises on any unexpected message, so lack of errors proves that no
        # start, unsubscribe or close was invoked on the external client
        expect { admin.with_consumer { nil } }.not_to raise_error
      end

      it "does not manage the external client lifecycle also when the block raises" do
        expect { admin.with_consumer { raise ArgumentError } }.to raise_error(ArgumentError)
      end

      it "ignores provided settings" do
        admin.with_consumer("group.id": "whatever") do |proxy|
          expect(proxy.wrapped).to eq(external_client)
        end
      end

      it "returns the block result" do
        expect(admin.with_consumer { 42 }).to eq(42)
      end
    end
  end

  describe "#with_admin" do
    context "when the external client is an rdkafka admin instance" do
      subject(:admin) { described_class.new(external_client: external_client) }

      let(:external_client) do
        Rdkafka::Config.new("bootstrap.servers": "127.0.0.1:9092").admin
      end

      after { external_client.close }

      it "yields a proxy wrapping the external admin and leaves it open" do
        admin.with_admin do |proxy|
          expect(proxy).to be_a(Karafka::Connection::Proxy)
          expect(proxy.wrapped).to eq(external_client)
        end

        expect(external_client.closed?).to be(false)
      end

      it "does not wrap an already proxied external admin with another proxy level" do
        proxied = Karafka::Connection::Proxy.new(external_client)

        described_class.new(external_client: proxied).with_admin do |proxy|
          expect(proxy.wrapped).to eq(external_client)
        end
      end

      it "leaves the external admin open also when the block raises" do
        expect { admin.with_admin { raise ArgumentError } }.to raise_error(ArgumentError)
        expect(external_client.closed?).to be(false)
      end

      it "is not used for consumer-based operations" do
        admin.with_consumer do |proxy|
          expect(proxy.wrapped).not_to eq(external_client)
        end
      end

      it "serves cluster_info without a dedicated admin instance" do
        # Materialize the external admin upfront so only operational usage is guarded
        admin.external_client

        expect(Rdkafka::Config).not_to receive(:new)

        expect(admin.cluster_info.topics).to be_a(Array)
      end
    end

    context "when the external client is a consumer" do
      subject(:admin) { described_class.new(external_client: external_client) }

      let(:external_client) { instance_double(Rdkafka::Consumer) }

      it "is not used and a dedicated admin instance operates" do
        admin.with_admin do |proxy|
          expect(proxy.wrapped).not_to eq(external_client)
        end
      end
    end
  end

  describe "external client delegations" do
    subject(:admin) { described_class.new(external_client: external_client) }

    let(:external_client) { instance_double(Rdkafka::Consumer) }

    it "carries the external client over to consumer groups operations" do
      expect(Karafka::Admin::ConsumerGroups)
        .to receive(:new)
        .with(kafka: {}, external_client: external_client)
        .and_call_original

      allow_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:read_lags_with_offsets)

      admin.read_lags_with_offsets
    end

    it "carries the external client over to topics operations" do
      expect(Karafka::Admin::Topics)
        .to receive(:new)
        .with(kafka: {}, external_client: external_client)
        .and_call_original

      allow_any_instance_of(Karafka::Admin::Topics).to receive(:info)

      admin.topic_info(name)
    end
  end

  describe "#close" do
    subject(:admin) { described_class.new }

    it "responds to close" do
      expect(admin).to respond_to(:close)
    end

    it "returns nil" do
      expect(admin.close).to be_nil
    end

    it "can be called multiple times without error" do
      expect { 3.times { admin.close } }.not_to raise_error
    end
  end
end
