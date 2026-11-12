# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:consumer) do
    instance = Class.new(Karafka::ShareConsumer).new
    instance.singleton_class.include(described_class)
    instance.client = client
    instance.coordinator = coordinator
    instance.producer = producer
    instance.messages = messages
    instance
  end

  let(:client) do
    instance_double(
      Karafka::Connection::ShareGroups::Client,
      mark_as_accepted: true,
      mark_as_released: true,
      mark_as_rejected: true,
      commit: nil
    )
  end

  let(:producer) { instance_double(WaterDrop::Producer, produce_async: nil, produce_sync: nil) }
  let(:topic) { build(:routing_share_topic).tap { |t| t.dead_letter_queue(topic: "dlq", max_retries: 2) } }
  let(:coordinator) { Karafka::Processing::ShareGroups::Coordinator.new(topic, 0) }
  let(:message) { build(:messages_message, raw_payload: "payload") }
  let(:messages) { Karafka::Messages::Builders::Messages.call([message], topic, 0, Time.now) }

  before { message.metadata.delivery_count = delivery_count }

  describe "#handle_after_consume" do
    before { coordinator.increment(:consume) }

    context "when consumption failed and retries are not exhausted" do
      let(:delivery_count) { 2 }

      before do
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).not_to have_received(:mark_as_rejected) }
      it { expect(client).to have_received(:mark_as_released).with(message) }
    end

    context "when consumption failed and retries are exhausted" do
      let(:delivery_count) { 3 }

      before do
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it "dispatches the raw payload to the dlq topic" do
        expect(producer).to have_received(:produce_async).with(topic: "dlq", payload: "payload")
      end

      it { expect(client).to have_received(:mark_as_rejected).with(message) }
    end

    context "when the dlq topic is false" do
      let(:delivery_count) { 3 }
      let(:topic) do
        build(:routing_share_topic).tap { |t| t.dead_letter_queue(topic: false, max_retries: 2) }
      end

      before do
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).to have_received(:mark_as_rejected).with(message) }
    end

    context "when the exhausted record was already acknowledged by the consumer" do
      let(:delivery_count) { 3 }

      before do
        consumer.mark_as_accepted(message)
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).not_to have_received(:mark_as_rejected) }
    end

    context "when the batch has more records left unacknowledged" do
      let(:delivery_count) { 3 }
      let(:accepted) { build(:messages_message, raw_payload: "accepted") }
      let(:other) { build(:messages_message, raw_payload: "other") }
      let(:messages) do
        Karafka::Messages::Builders::Messages.call([accepted, message, other], topic, 0, Time.now)
      end

      before do
        accepted.metadata.delivery_count = 3
        other.metadata.delivery_count = 3
        consumer.mark_as_accepted(accepted)
        coordinator.failure!(consumer, StandardError.new)
        consumer.handle_after_consume
      end

      it "dispatches only the first unacknowledged record" do
        expect(producer).to have_received(:produce_async).once
        expect(producer).to have_received(:produce_async).with(topic: "dlq", payload: "payload")
      end

      it { expect(client).to have_received(:mark_as_rejected).with(message).once }
      it { expect(client).to have_received(:mark_as_released).with(other) }
      it { expect(client).not_to have_received(:mark_as_rejected).with(other) }
    end

    context "when the failure is process-critical" do
      let(:delivery_count) { 3 }

      before do
        coordinator.failure!(consumer, SignalException.new("TERM"))
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).to have_received(:mark_as_released).with(message) }
    end

    context "when consumption succeeded" do
      let(:delivery_count) { 3 }

      before do
        coordinator.success!(consumer)
        consumer.handle_after_consume
      end

      it { expect(producer).not_to have_received(:produce_async) }
      it { expect(client).to have_received(:mark_as_released).with(message) }
    end
  end
end
