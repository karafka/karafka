# frozen_string_literal: true

RSpec.describe_current do
  let(:name) { SecureRandom.hex(6) }
  let(:topics) { Karafka::Admin.cluster_info.topics.map { |tp| tp[:topic_name] } }

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

        ::Karafka.producer.produce_sync(topic: name, payload: '1')
      end

      it { expect(reading.size).to eq(1) }
      it { expect(reading.first.offset).to eq(0) }
      it { expect(reading.first.raw_payload).to eq('1') }
    end

    context 'when trying to read less than in topic' do
      let(:count) { 5 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        ::Karafka.producer.produce_many_sync(messages)
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

        ::Karafka.producer.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(0) }
    end

    context 'when trying to get too much data from a custom offset' do
      let(:count) { 1_000 }
      let(:offset) { 3 }

      before do
        described_class.create_topic(name, 1, 1)
        messages = Array.new(10) { |i| { topic: name, payload: i.to_s } }

        ::Karafka.producer.produce_many_sync(messages)
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

        ::Karafka.producer.produce_many_sync(messages)
      end

      it { expect(reading.size).to eq(3) }
      it { expect(reading.last.offset).to eq(5) }
      it { expect(reading.first.offset).to eq(3) }
    end

    context 'when trying to read from topic that is part of the routing' do
      let(:created_custom_deserializer) { rand }
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

        ::Karafka.producer.produce_many_sync(messages)
      end

      it 'expect to assign proper deserializer to messages' do
        expect(reading.first.deserializer).to eq(created_custom_deserializer)
      end

      it 'expect to user proper routes topic assigned to messages' do
        expect(reading.first.topic).to eq(name)
      end
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

  describe '#watermark_offsets' do
    subject(:offsets) { described_class.watermark_offsets(name, partition) }

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

        ::Karafka.producer.produce_many_sync(messages)
      end

      it { expect(offsets.first).to eq(0) }
      it { expect(offsets.last).to eq(10) }
    end
  end
end
