# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:buffer) { described_class.new }

  let(:message) do
    build(
      :messages_message,
      raw_key: 'message_key',
      raw_headers: {
        'schedule_source_type' => 'schedule',
        'schedule_target_epoch' => epoch
      }
    )
  end

  let(:message2) do
    build(
      :messages_message,
      raw_key: 'message_key2',
      raw_headers: {
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
        end.to yield_with_args(message)
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

    context 'when multiple messages have the same epoch' do
      let(:past_epoch) { Time.now.to_i - 100 }

      let(:message1) do
        build(
          :messages_message,
          raw_key: 'key1',
          offset: 100,
          raw_headers: {
            'schedule_source_type' => 'schedule',
            'schedule_target_epoch' => past_epoch
          }
        )
      end

      let(:message2) do
        build(
          :messages_message,
          raw_key: 'key2',
          offset: 50,
          raw_headers: {
            'schedule_source_type' => 'schedule',
            'schedule_target_epoch' => past_epoch
          }
        )
      end

      let(:message3) do
        build(
          :messages_message,
          raw_key: 'key3',
          offset: 150,
          raw_headers: {
            'schedule_source_type' => 'schedule',
            'schedule_target_epoch' => past_epoch
          }
        )
      end

      before do
        buffer << message1
        buffer << message2
        buffer << message3
      end

      it 'yields messages sorted by offset when epochs are the same' do
        dispatched = []
        buffer.for_dispatch { |msg| dispatched << msg }

        expect(dispatched).to eq([message2, message1, message3])
        expect(dispatched.map(&:offset)).to eq([50, 100, 150])
      end
    end

    context 'when messages have different epochs and some have the same epoch' do
      let(:epoch1) { Time.now.to_i - 200 }
      let(:epoch2) { Time.now.to_i - 100 }

      let(:message1) do
        build(
          :messages_message,
          raw_key: 'key1',
          offset: 100,
          raw_headers: {
            'schedule_source_type' => 'schedule',
            'schedule_target_epoch' => epoch2
          }
        )
      end

      let(:message2) do
        build(
          :messages_message,
          raw_key: 'key2',
          offset: 50,
          raw_headers: {
            'schedule_source_type' => 'schedule',
            'schedule_target_epoch' => epoch2
          }
        )
      end

      let(:message3) do
        build(
          :messages_message,
          raw_key: 'key3',
          offset: 75,
          raw_headers: {
            'schedule_source_type' => 'schedule',
            'schedule_target_epoch' => epoch1
          }
        )
      end

      before do
        buffer << message1
        buffer << message2
        buffer << message3
      end

      it 'yields messages sorted by epoch first, then by offset for same epoch' do
        dispatched = []
        buffer.for_dispatch { |msg| dispatched << msg }

        expect(dispatched).to eq([message3, message2, message1])
        expect(dispatched[0].headers['schedule_target_epoch']).to eq(epoch1)
        expect(dispatched[1].headers['schedule_target_epoch']).to eq(epoch2)
        expect(dispatched[1].offset).to eq(50)
        expect(dispatched[2].headers['schedule_target_epoch']).to eq(epoch2)
        expect(dispatched[2].offset).to eq(100)
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
