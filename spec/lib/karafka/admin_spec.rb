# frozen_string_literal: true

RSpec.describe_current do
  let(:name) { SecureRandom.hex(6) }
  let(:topics) { Karafka::Admin.cluster_info.topics.map { |tp| tp[:topic_name] } }

  describe '#create_topic and #cluster_info' do
    context 'when creating topic with one partition' do
      before { described_class.create_topic(name, 1, 1) }

      it { expect(topics).to include(name) }
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
  end
end
