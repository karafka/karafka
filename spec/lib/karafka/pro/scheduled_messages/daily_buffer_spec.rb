# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:buffer) { described_class.new }

  let(:message) do
    instance_double(
      Karafka::Messages::Message,
      key: 'message_key',
      headers: {
        'schedule_source_type' => 'schedule',
        'schedule_target_epoch' => epoch
      }
    )
  end

  let(:message2) do
    instance_double(
      Karafka::Messages::Message,
      key: 'message_key2',
      headers: {
        'schedule_source_type' => 'schedule',
        'schedule_target_epoch' => epoch
      }
    )
  end

  let(:epoch) { Time.now.to_i }

  describe '#size' do
    context 'when buffer is empty' do
      it 'returns 0' do
        expect(buffer.size).to eq(0)
      end
    end

    context 'when buffer has one message' do
      before { buffer << message }

      it 'returns 1' do
        expect(buffer.size).to eq(1)
      end
    end

    context 'when buffer has multiple messages with different keys' do
      before do
        buffer << message
        buffer << message2
      end

      it 'returns the correct size' do
        expect(buffer.size).to eq(2)
      end
    end
  end

  describe '#<<' do
    context 'when adding a message' do
      it 'adds the message to the buffer' do
        buffer << message
        expect(buffer.size).to eq(1)
      end
    end

    context 'when adding a tombstone message' do
      before do
        message.headers['schedule_source_type'] = 'tombstone'
        buffer << message
      end

      it 'removes the message from the buffer' do
        expect(buffer.size).to eq(0)
      end
    end
  end

  describe '#for_dispatch' do
    context 'when there are messages due for dispatch' do
      before { buffer << message }

      it 'yields messages that should be dispatched' do
        expect do |b|
          buffer.for_dispatch(&b)
        end.to yield_with_args(epoch, message)
      end
    end

    context 'when there are messages not yet due for dispatch' do
      let(:future_epoch) { Time.now.to_i + 3_600 }

      before do
        message.headers['schedule_target_epoch'] = future_epoch
        buffer << message
      end

      it 'does not yield any messages' do
        expect do |b|
          buffer.for_dispatch(&b)
        end.not_to yield_control
      end
    end
  end

  describe '#delete' do
    context 'when deleting an existing key' do
      before do
        buffer << message
        buffer.delete('message_key')
      end

      it 'removes the message from the buffer' do
        expect(buffer.size).to eq(0)
      end
    end

    context 'when deleting a non-existing key' do
      before { buffer.delete('non_existing_key') }

      it 'does not affect the buffer' do
        expect(buffer.size).to eq(0)
      end
    end
  end
end
