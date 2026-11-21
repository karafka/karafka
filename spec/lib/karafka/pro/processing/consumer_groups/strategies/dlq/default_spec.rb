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
    instance = consumer_class.new
    instance.coordinator = coordinator
    instance.producer = producer
    instance.singleton_class.include(Karafka::Pro::BaseConsumer)
    instance.singleton_class.include(described_class)
    instance
  end

  let(:combination) do
    %i[
      dead_letter_queue
    ]
  end

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:coordinator) { build(:processing_coordinator_pro) }
  let(:producer) { instance_double(WaterDrop::Producer, produce_async: true) }
  let(:message) { build(:messages_message, raw_payload: "broken") }

  before { coordinator.topic.dead_letter_queue(topic: "dlq-topic") }

  it { expect(described_class::FEATURES).to eq(combination) }

  describe "#dispatch_to_dead_letter_queue" do
    it "expect to dispatch the payload to the DLQ topic" do
      consumer.dispatch_to_dead_letter_queue(message)

      expect(producer).to have_received(:produce_async)
        .with(hash_including(topic: "dlq-topic", payload: "broken"))
    end

    context "when consumer defines #enhance_dead_letter_queue_message" do
      let(:consumer_class) do
        Class.new(Karafka::BaseConsumer) do
          private

          def enhance_dead_letter_queue_message(dlq_message, _skippable_message)
            dlq_message[:headers]["enhanced"] = "new"
          end
        end
      end

      it "expect to use it to enhance the DLQ message" do
        consumer.dispatch_to_dead_letter_queue(message)

        expect(producer).to have_received(:produce_async)
          .with(hash_including(headers: hash_including("enhanced" => "new")))
      end
    end

    context "when consumer defines the deprecated #enhance_dlq_message" do
      let(:consumer_class) do
        Class.new(Karafka::BaseConsumer) do
          private

          def enhance_dlq_message(dlq_message, _skippable_message)
            dlq_message[:headers]["enhanced"] = "old"
          end
        end
      end

      it "expect to still use it to enhance the DLQ message" do
        consumer.dispatch_to_dead_letter_queue(message)

        expect(producer).to have_received(:produce_async)
          .with(hash_including(headers: hash_including("enhanced" => "old")))
      end
    end

    context "when consumer defines both enhancement methods" do
      let(:consumer_class) do
        Class.new(Karafka::BaseConsumer) do
          private

          def enhance_dead_letter_queue_message(dlq_message, _skippable_message)
            dlq_message[:headers]["enhanced"] = "new"
          end

          def enhance_dlq_message(dlq_message, _skippable_message)
            dlq_message[:headers]["enhanced"] = "old"
          end
        end
      end

      it "expect to use only #enhance_dead_letter_queue_message" do
        consumer.dispatch_to_dead_letter_queue(message)

        expect(producer).to have_received(:produce_async)
          .with(hash_including(headers: hash_including("enhanced" => "new")))
      end
    end
  end

  describe "#dispatch_to_dlq" do
    it "expect to keep dispatching to the DLQ topic under the deprecated name" do
      consumer.dispatch_to_dlq(message)

      expect(producer).to have_received(:produce_async)
        .with(hash_including(topic: "dlq-topic", payload: "broken"))
    end
  end
end
