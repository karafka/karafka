# frozen_string_literal: true

RSpec.describe_current do
  let(:name) { SecureRandom.hex(6) }
  let(:topics) { described_class.cluster_info.topics.map { |tp| tp[:topic_name] } }

  describe '#create_topic and #cluster_info' do
    context 'when creating topic with one partition' do
      before { described_class.create_topic(name, 1, 1) }

      it { expect(topics).to include(name) }
    end

    context 'when creating topic with invalid setup' do
      it do
        expect { described_class.create_topic('%^&*', 1, 1) }
          .to raise_error(Rdkafka::RdkafkaError)
      end
    end

    context 'when creating topic with two partitions' do
      before { described_class.create_topic(name, 2, 1) }

      it { expect(topics).to include(name) }
    end
  end

  describe '#delete_topic and #cluster_info' do
    before do
      described_class.create_topic(name, 2, 1)
      described_class.delete_topic(name)
    end

    it { expect(topics).not_to include(name) }
  end

  describe '#read_topic' do
    subject(:reading) { described_class.read_topic(name, partition, count, offset) }

    let(:name) { SecureRandom.hex(6) }
    let(:partition) { 0 }
    let(:count) { 1 }
    let(:offset) { -1 }

    context 'when trying to read non-existing topic' do
      it { expect { reading }.to raise_error(Rdkafka::RdkafkaError) }
    end

    context 'when trying to read non-existing partition' do
      let(:partition) { 1 }

      before { described_class.create_topic(name, 1, 1) }

      it { expect { reading }.to raise_error(Rdkafka::RdkafkaError) }
    end

    context 'when trying to read empty topic' do
      before { described_class.create_topic(name, 1, 1) }

      it { expect(reading.size).to eq(0) }
    end

    context 'when trying to read more than in topic' do
      let(:count) { 100 }

      before do
        described_class.create_topic(name, 1, 1)

        PRODUCERS.regular.produce_sync(topic: name, payload: '1')
      end

      it { expect(reading.size).to eq(1) }
      it { expect(reading.first.offset).to eq(0) }
      it { expect(reading.first.raw_payload).to eq('1') }
    end

    context 'when trying to read data from topic with only aborted transactions' do
      let(:count) { 100 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.transactional.transaction do
          PRODUCERS.transactional.produce_many_async(messages)
          throw(:abort)
        end
      end

      it { expect(reading.size).to eq(0) }
    end

    context 'when trying to read data from topic with only committed transactions' do
      let(:count) { 100 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.transactional.produce_many_sync(messages)
        # Give the transaction some time to finalize under load
        sleep(1)
      end

      it { expect(reading.size).to eq(10) }
      it { expect(reading.first.offset).to eq(0) }
      it { expect(reading.first.raw_payload).to eq('0') }
    end

    context 'when trying to read data from topic with messages and aborted transactions' do
      let(:count) { 100 }

      before do
        described_class.create_topic(name, 1, 1)

        PRODUCERS.regular.produce_sync(topic: name, payload: '-1')

        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.transactional.transaction do
          PRODUCERS.transactional.produce_many_async(messages)
          throw(:abort)
        end
      end

      it { expect(reading.size).to eq(1) }
      it { expect(reading.first.offset).to eq(0) }
      it { expect(reading.first.raw_payload).to eq('-1') }
    end

    context 'when trying to read less than in topic' do
      let(:count) { 5 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(5) }
      it { expect(reading.first.offset).to eq(5) }
      it { expect(reading.last.offset).to eq(9) }
      it { expect(reading.first.raw_payload).to eq('5') }
      it { expect(reading.last.raw_payload).to eq('9') }
    end

    context 'when trying to read from a non-existing offset' do
      let(:count) { 5 }
      let(:offset) { 100 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(0) }
    end

    context 'when trying to get too much data from a custom offset' do
      let(:count) { 1_000 }
      let(:offset) { 3 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(7) }
      it { expect(reading.last.offset).to eq(9) }
      it { expect(reading.first.offset).to eq(3) }
    end

    context 'when trying to get some data with a custom offset' do
      let(:count) { 3 }
      let(:offset) { 3 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(3) }
      it { expect(reading.last.offset).to eq(5) }
      it { expect(reading.first.offset).to eq(3) }
    end

    context 'when trying to read from topic that is part of the routing' do
      let(:created_custom_deserializer) { ->(msg) { msg } }
      let(:count) { 1 }

      before do
        custom_deserializer = created_custom_deserializer
        defined_topic_name = name

        Karafka::App.config.internal.routing.builder.clear

        Karafka::App.config.internal.routing.builder.draw do
          topic defined_topic_name do
            consumer Class.new(Karafka::BaseConsumer)
            deserializer custom_deserializer
          end
        end

        described_class.create_topic(name, 1, 1)
        messages = Array.new(1) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it 'expect to assign proper deserializer to messages' do
        expect(reading.first.deserializers.payload).to eq(created_custom_deserializer)
      end

      it 'expect to user proper routes topic assigned to messages' do
        expect(reading.first.topic).to eq(name)
      end
    end

    context 'when trying to read empty topic from the future' do
      let(:offset) { Time.now + 60 }

      before { described_class.create_topic(name, 1, 1) }

      it { expect(reading.size).to eq(0) }
    end

    context 'when trying to read topic with data from the future' do
      let(:offset) { Time.now + 60 }

      before do
        described_class.create_topic(name, 1, 1)

        PRODUCERS.regular.produce_sync(topic: name, payload: '1')
      end

      it { expect(reading.size).to eq(1) }
      it { expect(reading.first.offset).to eq(0) }
      it { expect(reading.first.raw_payload).to eq('1') }
    end

    context 'when reading from far in the past' do
      let(:count) { 10 }
      let(:offset) { Time.now - 60 * 5 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(20) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(10) }
      it { expect(reading.last.offset).to eq(9) }
      it { expect(reading.first.offset).to eq(0) }
    end

    context 'when reading from far in the past on a higher partition' do
      let(:count) { 10 }
      let(:offset) { Time.now - 60 * 5 }
      let(:partition) { 5 }

      before do
        described_class.create_topic(name, partition + 1, 1)
        messages = Array.new(20) { |i| { topic: name, payload: i.to_s, partition: partition } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(10) }
      it { expect(reading.last.offset).to eq(9) }
      it { expect(reading.first.offset).to eq(0) }
      it { expect(reading.first.partition).to eq(partition) }
    end

    context 'when reading from far in the past and trying to read more than present' do
      let(:count) { 1_000 }
      let(:offset) { Time.now - 60 * 5 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(10) }
      it { expect(reading.last.offset).to eq(9) }
      it { expect(reading.first.offset).to eq(0) }
    end

    context 'when reading from a negative offset to read few messages' do
      let(:count) { 2 }
      let(:offset) { -2 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(20) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(2) }
      it { expect(reading.last.offset).to eq(18) }
      it { expect(reading.first.offset).to eq(17) }
    end

    context 'when reading from a too low negative offset to read few messages' do
      let(:count) { 2 }
      let(:offset) { -10_000 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(20) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(2) }
      it { expect(reading.last.offset).to eq(1) }
      it { expect(reading.first.offset).to eq(0) }
    end

    # This may be a bit counter-intuitive in the first place.
    # We move the offset by -2 + 1 plus the requested count so we move it by 102 from high
    # watermark offset
    context 'when reading from a negative offset to read a lot but not enough data' do
      let(:count) { 100 }
      let(:offset) { -2 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(20) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(20) }
      it { expect(reading.last.offset).to eq(19) }
      it { expect(reading.first.offset).to eq(0) }
    end
  end

  describe '#create_partitions and #cluster_info' do
    context 'when scaling a topic that does not exist' do
      it do
        expect { described_class.create_partitions(SecureRandom.uuid, 2) }
          .to raise_error(Rdkafka::RdkafkaError)
      end
    end

    context 'when trying to downscale partitions' do
      before { described_class.create_topic(name, 2, 1) }

      it do
        expect { described_class.create_partitions(name, 1) }
          .to raise_error(Rdkafka::RdkafkaError)
      end
    end

    context 'when trying to match existing partitions' do
      before { described_class.create_topic(name, 2, 1) }

      it do
        expect { described_class.create_partitions(name, 2) }
          .to raise_error(Rdkafka::RdkafkaError)
      end
    end

    context 'when trying to upscale partitions' do
      let(:details) { Karafka::Admin.cluster_info.topics.find { |tp| tp[:topic_name] == name } }

      before do
        described_class.create_topic(name, 2, 1)
        described_class.create_partitions(name, 7)
      end

      it 'expect to create them' do
        expect(details[:partition_count]).to eq(7)
      end
    end
  end

  describe '#topic_info' do
    let(:name) { SecureRandom.uuid }

    context 'when given topic does not exist' do
      it { expect { described_class.topic_info(name) }.to raise_error(Rdkafka::RdkafkaError) }
    end

    context 'when given topic exists' do
      before { described_class.create_topic(name, 2, 1) }

      it do
        info = described_class.topic_info(name)
        expect(info[:partition_count]).to eq(2)
        expect(info[:topic_name]).to eq(name)
      end
    end
  end

  describe '#read_watermark_offsets' do
    subject(:offsets) { described_class.read_watermark_offsets(name, partition) }

    let(:name) { SecureRandom.hex(6) }
    let(:partition) { 0 }

    context 'when trying to read non-existing topic' do
      it { expect { offsets }.to raise_error(Rdkafka::RdkafkaError) }
    end

    context 'when trying to read non-existing partition' do
      let(:partition) { 1 }

      before { described_class.create_topic(name, 1, 1) }

      it { expect { offsets }.to raise_error(Rdkafka::RdkafkaError) }
    end

    context 'when getting watermarks from an empty partition' do
      before { described_class.create_topic(name, 1, 1) }

      it { expect(offsets.first).to eq(0) }
      it { expect(offsets.last).to eq(0) }
    end

    context 'when getting watermarks from partition with data (not compacted)' do
      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        PRODUCERS.regular.produce_many_sync(messages)
      end

      it { expect(offsets.first).to eq(0) }
      it { expect(offsets.last).to eq(10) }
    end
  end

  # More specs in the integrations
  describe '#seek_consumer_group' do
    subject(:seeking) { described_class.seek_consumer_group(cg_id, map) }

    let(:cg_id) { SecureRandom.uuid }
    let(:topic) { SecureRandom.uuid }
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
  describe '#rename_consumer_group' do
    subject(:rename) { described_class.rename_consumer_group(previous_name, new_name, topics) }

    let(:previous_name) { rand.to_s }
    let(:new_name) { rand.to_s }
    let(:topics) { [rand.to_s] }

    context 'when old name does not exist' do
      it { expect { rename }.to raise_error(Rdkafka::RdkafkaError, /group_id_not_found/) }
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
