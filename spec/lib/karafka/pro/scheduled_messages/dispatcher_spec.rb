# frozen_string_literal: true

RSpec.describe_current do
  subject(:dispatcher) { described_class.new(topic, partition) }

  let(:prefix) { rand.to_s }
  let(:topic) { "#{prefix}messages" }
  let(:partition) { rand(100) }
  let(:producer) { Karafka.producer }
  let(:tracker) { Karafka::Pro::ScheduledMessages::Tracker.new }
  let(:serializer) { Karafka::Pro::ScheduledMessages::Serializer.new }
  let(:schema_version) { Karafka::Pro::ScheduledMessages::SCHEMA_VERSION }
  let(:key) { rand.to_s }

  let(:raw_headers) do
    {
      'special' => 'header',
      'schedule_target_topic' => 'target_topic',
      'schedule_target_partition' => 2,
      'schedule_target_key' => '4',
      'schedule_target_partition_key' => 'pk'
    }
  end

  let(:message) do
    create(
      :messages_message,
      topic: topic,
      partition: partition,
      raw_key: key,
      raw_headers: raw_headers
    )
  end

  before do
    allow(producer).to receive(:produce_async)
    allow(producer).to receive(:produce_many_sync)
    allow(serializer.class).to receive(:new).and_return(serializer)
  end

  describe '#<<' do
    let(:buffer) { dispatcher.buffer }
    let(:piped) { buffer[0] }
    let(:tombstone) { buffer[1] }

    before { dispatcher << message }

    it { expect(buffer.size).to eq(2) }
    it { expect(piped[:topic]).to eq('target_topic') }
    it { expect(piped[:partition]).to eq(2) }
    it { expect(piped[:partition_key]).to eq('pk') }
    it { expect(piped[:key]).to eq('4') }
    it { expect(piped[:headers]['schedule_source_topic']).to eq(topic) }
    it { expect(piped[:headers]['schedule_source_partition']).to eq(partition.to_s) }
    it { expect(piped[:headers]['schedule_source_offset']).to eq(message.offset.to_s) }
    it { expect(piped[:headers]['schedule_source_key']).to eq(message.key) }
    it { expect(tombstone[:topic]).to eq(topic) }
    it { expect(tombstone[:partition]).to eq(partition) }
    it { expect(tombstone[:payload]).to eq(nil) }
    it { expect(tombstone[:key]).to eq(message.key) }
    it { expect(tombstone[:headers]['schedule_source_type']).to eq('tombstone') }
    it { expect(tombstone[:headers]['schedule_schema_version']).to eq(schema_version) }

    context 'when key is not available' do
      let(:raw_headers) do
        {
          'special' => 'header',
          'schedule_target_topic' => 'target_topic',
          'schedule_target_partition' => 2,
          'schedule_target_partition_key' => 'pk'
        }
      end

      before do
        buffer.clear
        dispatcher << message
      end

      it { expect(piped.key?(:key)).to eq(false) }
    end
  end

  describe '#flush' do
    before { dispatcher << message }

    it 'expect to dispatch all 3 messages' do
      messages = dispatcher.buffer.dup
      dispatcher.flush
      expect(producer).to have_received(:produce_many_sync).with(messages)
      expect(dispatcher.buffer).to be_empty
    end
  end

  describe '#state' do
    before { allow(serializer).to receive(:state).with(tracker).and_return(serializer_result) }

    let(:serializer_result) { rand.to_s }
    let(:expected) do
      {
        topic: "#{topic}_states",
        payload: serializer_result,
        key: 'state',
        partition: partition,
        headers: { 'zlib' => 'true' }
      }
    end

    it 'expect to dispatch sync with proper details and to proper target topic partition' do
      dispatcher.state(tracker)

      expect(producer)
        .to have_received(:produce_async)
        .with(expected)
    end
  end
end
