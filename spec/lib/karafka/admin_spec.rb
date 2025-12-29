# frozen_string_literal: true

RSpec.describe_current do
  let(:name) { "it-#{SecureRandom.uuid}" }
  let(:topics) { described_class.cluster_info.topics.map { |tp| tp[:topic_name] } }

  describe '#create_topic' do
    it 'delegates to Admin::Topics#create' do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:create).with(name, 2, 1, {})
      described_class.create_topic(name, 2, 1)
    end

    it 'passes through topic_config parameter' do
      config = { 'cleanup.policy' => 'compact' }
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:create).with(name, 2, 1, config)
      described_class.create_topic(name, 2, 1, config)
    end
  end

  describe '#delete_topic' do
    it 'delegates to Admin::Topics#delete' do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:delete).with(name)
      described_class.delete_topic(name)
    end
  end

  describe '#read_topic' do
    let(:partition) { 0 }
    let(:count) { 1 }
    let(:offset) { -1 }
    let(:settings) { {} }

    it 'delegates to Admin::Topics#read with all parameters' do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:read).with(name, partition, count, offset, settings)
      described_class.read_topic(name, partition, count, offset, settings)
    end

    it 'delegates to Admin::Topics#read with default parameters' do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:read).with(name, partition, count, -1, {})
      described_class.read_topic(name, partition, count)
    end
  end

  describe '#create_partitions' do
    let(:partitions) { 7 }

    it 'delegates to Admin::Topics#create_partitions' do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:create_partitions).with(name, partitions)
      described_class.create_partitions(name, partitions)
    end
  end

  describe '#topic_info' do
    it 'delegates to Admin::Topics#info' do
      expect_any_instance_of(Karafka::Admin::Topics)
        .to receive(:info).with(name)
      described_class.topic_info(name)
    end
  end

  describe '#read_watermark_offsets' do
    let(:partition) { 0 }
    let(:topics_with_partitions) { { name => [0, 1] } }

    context 'when called with topic and partition' do
      it 'delegates to Admin::Topics#read_watermark_offsets' do
        expect_any_instance_of(Karafka::Admin::Topics)
          .to receive(:read_watermark_offsets).with(name, partition)
        described_class.read_watermark_offsets(name, partition)
      end
    end

    context 'when called with topics hash' do
      it 'delegates to Admin::Topics#read_watermark_offsets' do
        expect_any_instance_of(Karafka::Admin::Topics)
          .to receive(:read_watermark_offsets).with(topics_with_partitions, nil)
        described_class.read_watermark_offsets(topics_with_partitions)
      end
    end
  end

  # More specs in the integrations
  describe '#seek_consumer_group' do
    let(:cg_id) { SecureRandom.uuid }
    let(:map) { { 'topic' => { 0 => 10 } } }

    it 'delegates to ConsumerGroups#seek' do
      expect_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:seek).with(cg_id, map)
      described_class.seek_consumer_group(cg_id, map)
    end
  end

  describe '#copy_consumer_group' do
    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    it 'delegates to ConsumerGroups#copy' do
      expect_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:copy).with(previous_name, new_name, topics)
      described_class.copy_consumer_group(previous_name, new_name, topics)
    end
  end

  describe '#rename_consumer_group' do
    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    context 'when delete_previous is not specified' do
      it 'delegates to ConsumerGroups#rename with default delete_previous' do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:rename)
          .with(previous_name, new_name, topics, delete_previous: true)
        described_class.rename_consumer_group(previous_name, new_name, topics)
      end
    end

    context 'when delete_previous is specified' do
      it 'delegates to ConsumerGroups#rename with specified delete_previous' do
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

  describe '#delete_consumer_group' do
    let(:cg_id) { SecureRandom.uuid }

    it 'delegates to ConsumerGroups#delete' do
      expect_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:delete).with(cg_id)
      described_class.delete_consumer_group(cg_id)
    end
  end

  describe '#trigger_rebalance' do
    let(:cg_id) { SecureRandom.uuid }

    it 'delegates to ConsumerGroups#trigger_rebalance' do
      expect_any_instance_of(Karafka::Admin::ConsumerGroups)
        .to receive(:trigger_rebalance).with(cg_id)
      described_class.trigger_rebalance(cg_id)
    end
  end

  describe '#read_lags_with_offsets' do
    let(:cgs_t) { { 'test_cg' => ['test_topic'] } }

    context 'when active_topics_only is not specified' do
      it 'delegates to ConsumerGroups#read_lags_with_offsets with default active_topics_only' do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:read_lags_with_offsets)
          .with(cgs_t, active_topics_only: true)
        described_class.read_lags_with_offsets(cgs_t)
      end
    end

    context 'when active_topics_only is specified' do
      it 'delegates to ConsumerGroups#read_lags_with_offsets with specified active_topics_only' do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:read_lags_with_offsets)
          .with(cgs_t, active_topics_only: false)
        described_class.read_lags_with_offsets(cgs_t, active_topics_only: false)
      end
    end

    context 'when consumer_groups_with_topics is not specified' do
      it 'delegates to ConsumerGroups#read_lags_with_offsets with empty hash' do
        expect_any_instance_of(Karafka::Admin::ConsumerGroups)
          .to receive(:read_lags_with_offsets)
          .with({}, active_topics_only: true)
        described_class.read_lags_with_offsets
      end
    end
  end
end
