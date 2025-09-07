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

    it 'delegates to Admin::Topics.read_watermark_offsets' do
      allow(Karafka::Admin::Topics).to receive(:read_watermark_offsets)
      described_class.read_watermark_offsets(name, partition)
      expect(Karafka::Admin::Topics)
        .to have_received(:read_watermark_offsets).with(name, partition)
    end
  end

  # More specs in the integrations
  describe '#seek_consumer_group' do
    subject(:seeking) { described_class.seek_consumer_group(cg_id, map) }

    let(:cg_id) { SecureRandom.uuid }
    let(:topic) { name }
    let(:partition) { 0 }
    let(:offset) { 0 }
    let(:map) { { topic => { partition => offset } } }

    before { described_class.create_topic(topic, 1, 1) }

    context 'when given consumer group does not exist' do
      it 'expect not to throw error and operate' do
        expect { seeking }.not_to raise_error
      end
    end

    context 'when using the topic level map' do
      let(:map) { { topic => offset } }

      it 'expect not to throw error and operate' do
        expect { seeking }.not_to raise_error
      end
    end

    context 'when using the topic level map with time reference on empty topic' do
      let(:offset) { Time.now - 60 }
      let(:map) { { topic => offset } }

      it 'expect not to throw error and operate' do
        expect { seeking }.not_to raise_error
      end
    end
  end

  # More specs in the integrations
  describe '#copy_consumer_group' do
    subject(:rename) { described_class.copy_consumer_group(previous_name, new_name, topics) }

    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    context 'when old name does not exist' do
      it 'expect not to raise error because it will not have offsets for old cg' do
        expect(rename).to be(false)
      end
    end

    context 'when old name exists but no topics to migrate are given' do
      let(:topics) { [] }

      it { expect { rename }.not_to raise_error }
      it { expect(rename).to be(false) }
    end

    context 'when requested topics do not exist but CG does' do
      before do
        described_class.create_topic(name, 1, 1)
        described_class.seek_consumer_group(previous_name, name => { 0 => 10 })
      end

      it { expect { rename }.not_to raise_error }
      it { expect(rename).to be(false) }
    end
  end

  # More specs in the integrations
  describe '#rename_consumer_group' do
    subject(:rename) { described_class.rename_consumer_group(previous_name, new_name, topics) }

    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    context 'when old name does not exist' do
      it { expect(rename).to be(false) }
    end

    context 'when old name exists but no topics to migrate are given' do
      let(:topics) { [] }

      it { expect { rename }.not_to raise_error }
    end

    context 'when requested topics do not exist but CG does' do
      before do
        described_class.create_topic(name, 1, 1)
        described_class.seek_consumer_group(previous_name, name => { 0 => 10 })
      end

      it { expect { rename }.not_to raise_error }
      it { expect(rename).to be(false) }
    end
  end

  describe '#delete_consumer_group' do
    subject(:removal) { described_class.delete_consumer_group(cg_id) }

    context 'when requested consumer group does not exist' do
      let(:cg_id) { SecureRandom.uuid }

      it do
        expect { removal }.to raise_error(Rdkafka::RdkafkaError)
      end
    end

    # The case where given consumer group exists we check in the integrations, because it is
    # much easier to test with integrations on created consumer group
  end

  # More coverage of this feature is in integration suite
  describe '#read_lags_with_offsets' do
    subject(:results) { Karafka::Admin.read_lags_with_offsets(cgs_t) }

    context 'when we query for a non-existent topic with a non-existing CG' do
      let(:cgs_t) { { 'doesnotexist' => ['doesnotexisttopic'] } }

      it { expect(results).to eq('doesnotexist' => { 'doesnotexisttopic' => {} }) }
    end

    context 'when querying existing topic with a CG that never consumed it' do
      before { PRODUCERS.regular.produce_sync(topic: name, payload: '1') }

      let(:cgs_t) { { 'doesnotexist' => [name] } }

      it { expect(results).to eq('doesnotexist' => { name => { 0 => { lag: -1, offset: -1 } } }) }
    end
  end
end
