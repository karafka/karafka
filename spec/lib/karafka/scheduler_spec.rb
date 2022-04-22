# frozen_string_literal: true

RSpec.describe_current do
  subject(:scheduler) { described_class.new }

  let(:messages_buffer) { Karafka::Connection::MessagesBuffer.new }

  context 'when there are no messages' do
    it { expect { |block| scheduler.call(messages_buffer, &block) }.not_to yield_control }
  end

  context 'when there are messages' do
    2.times do |topic_nr|
      2.times do |partition_nr|
        2.times do |message_nr|
          let(:"t#{topic_nr}p#{partition_nr}m#{message_nr}") do
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
    end

    let(:yielded) do
      data = []

      scheduler.call(messages_buffer) do |topic, partition, messages|
        data << [topic, partition, messages]
      end

      data
    end

    let(:expected) do
      [
        [t0p0m0.topic, t0p0m0.partition, [t0p0m0, t0p0m1]],
        [t0p1m0.topic, t0p1m0.partition, [t0p1m0, t0p1m1]],
        [t1p0m0.topic, t1p0m0.partition, [t1p0m0, t1p0m1]],
        [t1p1m0.topic, t1p1m0.partition, [t1p1m0, t1p1m1]]
      ]
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
      expect(yielded).to eq(expected)
    end
  end
end
