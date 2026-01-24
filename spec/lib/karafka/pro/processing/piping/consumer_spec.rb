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

# end-to-end specs in the integration suite
RSpec.describe_current do
  let(:consumer_class) do
    topic_reference = build(:routing_topic)

    Class.new(Karafka::BaseConsumer) do
      include Karafka::Pro::Processing::Piping::Consumer

      define_method :topic do
        topic_reference
      end
    end
  end

  let(:topic) { 'test_topic' }

  let(:message) do
    build(
      :messages_message,
      topic: topic,
      partition: 1,
      raw_key: 'key',
      raw_payload: 'message_payload'
    )
  end

  let(:consumer_instance) { consumer_class.new }

  describe '#pipe_async' do
    before { allow(consumer_instance).to receive(:produce_async) }

    it 'calls produce_async with the correct message' do
      consumer_instance.pipe_async(topic: topic, message: message)

      expect(consumer_instance)
        .to have_received(:produce_async)
        .with(hash_including(topic: topic, key: 'key', payload: 'message_payload'))
    end

    context 'when there is no key' do
      let(:message) do
        build(
          :messages_message,
          topic: topic,
          partition: 1,
          raw_payload: 'message_payload'
        )
      end

      it 'calls produce_sync with the partition as a key' do
        consumer_instance.pipe_async(topic: topic, message: message)

        expect(consumer_instance)
          .to have_received(:produce_async)
          .with(hash_including(topic: topic, key: '1', payload: 'message_payload'))
      end
    end
  end

  describe '#pipe_sync' do
    before { allow(consumer_instance).to receive(:produce_sync) }

    it 'calls produce_sync with the correct message' do
      consumer_instance.pipe_sync(topic: topic, message: message)

      expect(consumer_instance)
        .to have_received(:produce_sync)
        .with(hash_including(topic: topic, key: 'key', payload: 'message_payload'))
    end

    context 'when there is no key' do
      let(:message) do
        build(
          :messages_message,
          topic: topic,
          partition: 1,
          raw_payload: 'message_payload'
        )
      end

      it 'calls produce_sync with the partition as a key' do
        consumer_instance.pipe_sync(topic: topic, message: message)

        expect(consumer_instance)
          .to have_received(:produce_sync)
          .with(hash_including(topic: topic, key: '1', payload: 'message_payload'))
      end
    end
  end

  describe '#pipe_many_async' do
    before { allow(consumer_instance).to receive(:produce_many_async) }

    it 'calls produce_many_async with the correct messages' do
      messages = [message, message]
      consumer_instance.pipe_many_async(topic: topic, messages: messages)
      expect(consumer_instance).to have_received(:produce_many_async).with(Array)
    end
  end

  describe '#pipe_many_sync' do
    before { allow(consumer_instance).to receive(:produce_many_sync) }

    it 'calls produce_many_sync with the correct messages' do
      messages = [message, message]
      consumer_instance.pipe_many_sync(topic: topic, messages: messages)
      expect(consumer_instance).to have_received(:produce_many_sync).with(Array)
    end
  end
end
