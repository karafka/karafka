# frozen_string_literal: true

RSpec.describe_current do
  subject(:scheduler) { described_class.new }

  let(:messages_buffer) { Karafka::Connection::MessagesBuffer.new }

  context 'when there are no messages' do
    it { expect { |block| scheduler.call(messages_buffer, &block) }.not_to yield_control }
  end

  context 'when there are messages' do
    [
      [0,0],
      [0,1],
      [1,0],
      [1,1]
    ].each do |topic_nr, partition_nr|
      2.times do |i|
        let(:"t#{topic_nr}p#{partition_nr}m#{i}") do
          build(
            :messages_message,
            metadata: build(
              :messages_metadata,
              topic: "topic#{topic_nr}",
              partition: partition_nr
            )
          )
        end
      end
    end

    let(:yielded) do
      data = []

      scheduler.call(messages_buffer) do |topic, partition, messages|
        data << [topic, partition, messages]
      end

      data
    end

    before do
      messages_buffer << t0p0m0
      messages_buffer << t0p0m1
      messages_buffer << t0p1m0
      messages_buffer << t0p1m1
      messages_buffer << t1p0m0
      messages_buffer << t1p0m1
      messages_buffer << t1p1m0
      messages_buffer << t1p1m1
    end

    it 'expect to yield them in the fifo order' do
      expect(yielded[0]).to eq([t0p0m0.topic, t0p0m0.partition, [t0p0m0, t0p0m1]])
      expect(yielded[1]).to eq([t0p1m0.topic, t0p1m0.partition, [t0p1m0, t0p1m1]])
      expect(yielded[2]).to eq([t1p0m0.topic, t1p0m0.partition, [t1p0m0, t1p0m1]])
      expect(yielded[3]).to eq([t1p1m0.topic, t1p1m0.partition, [t1p1m0, t1p1m1]])
    end
  end
end
