# frozen_string_literal: true

RSpec.describe_current do
  let(:name) { "it-#{SecureRandom.uuid}" }
  let(:topics) { described_class.cluster_info.topics.map { |tp| tp[:topic_name] } }

  describe '#create_topic' do
    it 'delegates to Admin::Topics.create' do
      allow(Karafka::Admin::Topics).to receive(:create)
      described_class.create_topic(name, 2, 1)
      expect(Karafka::Admin::Topics).to have_received(:create).with(name, 2, 1, {})
    end

    it 'passes through topic_config parameter' do
      config = { 'cleanup.policy' => 'compact' }
      allow(Karafka::Admin::Topics).to receive(:create)
      described_class.create_topic(name, 2, 1, config)
      expect(Karafka::Admin::Topics).to have_received(:create).with(name, 2, 1, config)
    end
  end

  describe '#delete_topic' do
    it 'delegates to Admin::Topics.delete' do
      allow(Karafka::Admin::Topics).to receive(:delete)
      described_class.delete_topic(name)
      expect(Karafka::Admin::Topics).to have_received(:delete).with(name)
    end
  end

  describe '#read_topic' do
    let(:partition) { 0 }
    let(:count) { 1 }
    let(:offset) { -1 }
    let(:settings) { {} }

    it 'delegates to Admin::Topics.read with all parameters' do
      allow(Karafka::Admin::Topics).to receive(:read)
      described_class.read_topic(name, partition, count, offset, settings)
      expect(Karafka::Admin::Topics)
        .to have_received(:read).with(name, partition, count, offset, settings)
    end

    it 'delegates to Admin::Topics.read with default parameters' do
      allow(Karafka::Admin::Topics).to receive(:read)
      described_class.read_topic(name, partition, count)
      expect(Karafka::Admin::Topics)
        .to have_received(:read).with(name, partition, count, -1, {})
    end
  end

  describe '#create_partitions' do
    let(:partitions) { 7 }

    it 'delegates to Admin::Topics.create_partitions' do
      allow(Karafka::Admin::Topics).to receive(:create_partitions)
      described_class.create_partitions(name, partitions)
      expect(Karafka::Admin::Topics)
        .to have_received(:create_partitions).with(name, partitions)
    end
  end

  describe '#topic_info' do
    it 'delegates to Admin::Topics.info' do
      allow(Karafka::Admin::Topics).to receive(:info)
      described_class.topic_info(name)
      expect(Karafka::Admin::Topics).to have_received(:info).with(name)
    end
  end

  describe '#read_watermark_offsets' do
    let(:partition) { 0 }
    let(:topics_with_partitions) { { name => [0, 1] } }

    context 'when called with topic and partition' do
      it 'delegates to Admin::Topics.read_watermark_offsets' do
        allow(Karafka::Admin::Topics).to receive(:read_watermark_offsets)
        described_class.read_watermark_offsets(name, partition)
        expect(Karafka::Admin::Topics)
          .to have_received(:read_watermark_offsets).with(name, partition)
      end
    end

    context 'when called with topics hash' do
      it 'delegates to Admin::Topics.read_watermark_offsets' do
        allow(Karafka::Admin::Topics).to receive(:read_watermark_offsets)
        described_class.read_watermark_offsets(topics_with_partitions)
        expect(Karafka::Admin::Topics)
          .to have_received(:read_watermark_offsets).with(topics_with_partitions, nil)
      end
    end
  end

  # More specs in the integrations
  describe '#seek_consumer_group' do
    let(:cg_id) { SecureRandom.uuid }
    let(:map) { { 'topic' => { 0 => 10 } } }

    before do
      allow(Karafka::Admin::ConsumerGroups).to receive(:seek)
    end

    it 'delegates to ConsumerGroups.seek' do
      described_class.seek_consumer_group(cg_id, map)
      expect(Karafka::Admin::ConsumerGroups).to have_received(:seek).with(cg_id, map)
    end
  end

  describe '#copy_consumer_group' do
    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    before do
      allow(Karafka::Admin::ConsumerGroups).to receive(:copy)
    end

    it 'delegates to ConsumerGroups.copy' do
      described_class.copy_consumer_group(previous_name, new_name, topics)
      expect(Karafka::Admin::ConsumerGroups)
        .to have_received(:copy).with(previous_name, new_name, topics)
    end
  end

  describe '#rename_consumer_group' do
    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    before do
      allow(Karafka::Admin::ConsumerGroups).to receive(:rename)
    end

    context 'when delete_previous is not specified' do
      it 'delegates to ConsumerGroups.rename with default delete_previous' do
        described_class.rename_consumer_group(previous_name, new_name, topics)
        expect(Karafka::Admin::ConsumerGroups)
          .to have_received(:rename)
          .with(previous_name, new_name, topics, delete_previous: true)
      end
    end

    context 'when delete_previous is specified' do
      it 'delegates to ConsumerGroups.rename with specified delete_previous' do
        described_class.rename_consumer_group(
          previous_name,
          new_name,
          topics,
          delete_previous: false
        )

        expect(Karafka::Admin::ConsumerGroups)
          .to have_received(:rename)
          .with(previous_name, new_name, topics, delete_previous: false)
      end
    end
  end

  describe '#delete_consumer_group' do
    let(:cg_id) { SecureRandom.uuid }

    before do
      allow(Karafka::Admin::ConsumerGroups).to receive(:delete)
    end

    it 'delegates to ConsumerGroups.delete' do
      described_class.delete_consumer_group(cg_id)
      expect(Karafka::Admin::ConsumerGroups).to have_received(:delete).with(cg_id)
    end
  end

  describe '#trigger_rebalance' do
    let(:cg_id) { SecureRandom.uuid }

    before do
      allow(Karafka::Admin::ConsumerGroups).to receive(:trigger_rebalance)
    end

    it 'delegates to ConsumerGroups.trigger_rebalance' do
      described_class.trigger_rebalance(cg_id)
      expect(Karafka::Admin::ConsumerGroups)
        .to have_received(:trigger_rebalance).with(cg_id)
    end
  end

  describe '#read_lags_with_offsets' do
    let(:cgs_t) { { 'test_cg' => ['test_topic'] } }

    before do
      allow(Karafka::Admin::ConsumerGroups).to receive(:read_lags_with_offsets)
    end

    context 'when active_topics_only is not specified' do
      it 'delegates to ConsumerGroups.read_lags_with_offsets with default active_topics_only' do
        described_class.read_lags_with_offsets(cgs_t)
        expect(Karafka::Admin::ConsumerGroups)
          .to have_received(:read_lags_with_offsets)
          .with(cgs_t, active_topics_only: true)
      end
    end

    context 'when active_topics_only is specified' do
      it 'delegates to ConsumerGroups.read_lags_with_offsets with specified active_topics_only' do
        described_class.read_lags_with_offsets(cgs_t, active_topics_only: false)
        expect(Karafka::Admin::ConsumerGroups)
          .to have_received(:read_lags_with_offsets)
          .with(cgs_t, active_topics_only: false)
      end
    end

    context 'when consumer_groups_with_topics is not specified' do
      it 'delegates to ConsumerGroups.read_lags_with_offsets with empty hash' do
        described_class.read_lags_with_offsets
        expect(Karafka::Admin::ConsumerGroups)
          .to have_received(:read_lags_with_offsets)
          .with({}, active_topics_only: true)
      end
    end
  end
end
