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
  let(:dlq_topic_name) { generate_topic_name }
  let(:target_topic_name) { generate_topic_name }
  let(:source_topic_name) { generate_topic_name }

  let(:target_messages) { Karafka::Admin.read_topic(target_topic_name, 0, 100, 0) }

  describe "#copy" do
    before do
      # Other specs can leave a custom producer as the app one
      allow(Karafka).to receive(:producer).and_return(PRODUCERS.regular)
      Karafka::Admin.create_topic(dlq_topic_name, 2, 1)
      Karafka::Admin.create_topic(target_topic_name, 1, 1)
    end

    context "when the arguments are invalid" do
      it "raises without dispatching" do
        expect { described_class.copy(dlq_topic_name, partitions: []) }
          .to raise_error(Karafka::Errors::InvalidConfigurationError)
      end
    end

    context "when copying to a target topic" do
      before do
        PRODUCERS.regular.produce_many_sync(
          [
            { topic: dlq_topic_name, partition: 0, payload: "0", key: "k0" },
            { topic: dlq_topic_name, partition: 1, payload: "1", headers: { "a" => "b" } }
          ]
        )
      end

      it "copies messages of all the partitions with their key and headers" do
        expect(described_class.copy(dlq_topic_name, target_topic_name: target_topic_name))
          .to eq(2)

        expect(target_messages.map(&:raw_payload)).to contain_exactly("0", "1")
        expect(target_messages.find { |m| m.raw_payload == "0" }.raw_key).to eq("k0")
        expect(target_messages.map(&:raw_headers)).to contain_exactly(
          { "replay_count" => "1" },
          { "a" => "b", "replay_count" => "1" }
        )
      end
    end

    context "when copying an offset range of given partitions" do
      before do
        PRODUCERS.regular.produce_many_sync(
          Array.new(10) { |i| { topic: dlq_topic_name, partition: 1, payload: i.to_s } } +
            [{ topic: dlq_topic_name, partition: 0, payload: "other" }]
        )
      end

      it "copies only the messages of the range" do
        expect(
          described_class.copy(
            dlq_topic_name,
            target_topic_name: target_topic_name,
            partitions: [1],
            start_offset: 3,
            end_offset: 6
          )
        ).to eq(3)

        expect(target_messages.map(&:raw_payload)).to eq(%w[3 4 5])
      end
    end

    context "when the start offset is a time" do
      let(:now_ms) { (Time.now.to_f * 1_000).to_i }

      before do
        PRODUCERS.regular.produce_many_sync(
          [
            { topic: dlq_topic_name, partition: 0, payload: "old", timestamp: now_ms - 600_000 },
            { topic: dlq_topic_name, partition: 0, payload: "new", timestamp: now_ms }
          ]
        )
      end

      it "copies the messages from that time" do
        expect(
          described_class.copy(
            dlq_topic_name,
            target_topic_name: target_topic_name,
            start_offset: Time.at((now_ms - 60_000) / 1_000.0)
          )
        ).to eq(1)

        expect(target_messages.map(&:raw_payload)).to eq(%w[new])
      end
    end

    context "when the end offset is above the high watermark" do
      before do
        PRODUCERS.regular.produce_many_sync(
          Array.new(3) { |i| { topic: dlq_topic_name, partition: 0, payload: i.to_s } }
        )
      end

      it "copies until the high watermark" do
        expect(
          described_class.copy(
            dlq_topic_name,
            target_topic_name: target_topic_name,
            partitions: [0],
            end_offset: 100
          )
        ).to eq(3)
      end
    end

    context "when copying more messages than one batch" do
      before do
        PRODUCERS.regular.produce_many_sync(
          Array.new(2_500) { |i| { topic: dlq_topic_name, partition: 0, payload: i.to_s } }
        )
      end

      let(:target_messages) { Karafka::Admin.read_topic(target_topic_name, 0, 3_000, 0) }

      it "copies all of them in order" do
        expect(described_class.copy(dlq_topic_name, target_topic_name: target_topic_name))
          .to eq(2_500)

        expect(target_messages.map(&:raw_payload)).to eq(Array.new(2_500, &:to_s))
      end
    end

    context "when the low watermark is above the batch size" do
      before do
        PRODUCERS.regular.produce_many_sync(
          Array.new(1_300) { |i| { topic: dlq_topic_name, partition: 0, payload: i.to_s } }
        )

        Karafka::Admin.delete_records({ dlq_topic_name => [{ partition: 0, offset: 1_200 }] })
      end

      it "copies from the low watermark" do
        expect(described_class.copy(dlq_topic_name, target_topic_name: target_topic_name))
          .to eq(100)

        expect(target_messages.map(&:raw_payload).first).to eq("1200")
      end
    end

    context "when an offset gap is larger than the batch size" do
      before do
        PRODUCERS.regular.produce_sync(topic: dlq_topic_name, partition: 0, payload: "first")

        PRODUCERS.transactional.transaction do
          PRODUCERS.transactional.produce_many_sync(
            Array.new(1_100) { { topic: dlq_topic_name, partition: 0, payload: "aborted" } }
          )

          raise WaterDrop::AbortTransaction
        end

        PRODUCERS.regular.produce_sync(topic: dlq_topic_name, partition: 0, payload: "last")
      end

      it "copies the messages after the gap" do
        expect(described_class.copy(dlq_topic_name, target_topic_name: target_topic_name))
          .to eq(2)

        expect(target_messages.map(&:raw_payload)).to eq(%w[first last])
      end
    end

    context "when messages land in the dead letter queue during the copy" do
      # Copies have no key or partition, so a single partition keeps them all in one place
      let(:single_topic_name) { generate_topic_name }

      before do
        Karafka::Admin.create_topic(single_topic_name, 1, 1)

        PRODUCERS.regular.produce_many_sync(
          Array.new(3) { |i| { topic: single_topic_name, partition: 0, payload: i.to_s } }
        )
      end

      it "does not copy them without an end offset" do
        expect(described_class.copy(single_topic_name, target_topic_name: single_topic_name, partitions: [0]))
          .to eq(3)

        expect(Karafka::Admin.read_watermark_offsets(single_topic_name, 0)).to eq([0, 6])
      end

      it "does not copy them with an end offset above the high watermark" do
        expect(
          described_class.copy(
            single_topic_name,
            target_topic_name: single_topic_name,
            partitions: [0],
            end_offset: 100
          )
        ).to eq(3)

        expect(Karafka::Admin.read_watermark_offsets(single_topic_name, 0)).to eq([0, 6])
      end
    end

    context "when partitions repeat" do
      it "raises without dispatching" do
        expect { described_class.copy(dlq_topic_name, target_topic_name: target_topic_name, partitions: [0, 0]) }
          .to raise_error(Karafka::Errors::InvalidConfigurationError)
      end
    end

    context "when the admin has a custom kafka configuration" do
      subject(:admin) { described_class.new(kafka: { "bootstrap.servers": "127.0.0.1:9092" }) }

      before do
        PRODUCERS.regular.produce_sync(topic: dlq_topic_name, partition: 0, payload: "0")
      end

      it "requires a producer" do
        expect { admin.copy(dlq_topic_name, target_topic_name: target_topic_name) }
          .to raise_error(Karafka::Errors::InvalidConfigurationError, /producer/)
      end

      it "reads with the custom kafka configuration" do
        expect(Karafka::Admin::Topics)
          .to receive(:new)
          .with(kafka: { "bootstrap.servers": "127.0.0.1:9092" }, external_client: nil)
          .and_call_original

        admin.copy(dlq_topic_name, target_topic_name: target_topic_name, producer: PRODUCERS.regular)
      end

      it "copies with the given producer" do
        expect(
          admin.copy(dlq_topic_name, target_topic_name: target_topic_name, producer: PRODUCERS.regular)
        ).to eq(1)
      end
    end

    context "when the start time is after the last message" do
      before do
        PRODUCERS.regular.produce_sync(topic: dlq_topic_name, partition: 0, payload: "0")
      end

      it "copies nothing" do
        expect(
          described_class.copy(
            dlq_topic_name,
            target_topic_name: target_topic_name,
            start_offset: Time.now + 60
          )
        ).to eq(0)
      end
    end

    context "when the dead letter queue is empty" do
      it { expect(described_class.copy(dlq_topic_name, target_topic_name: target_topic_name)).to eq(0) }
    end

    context "when messages have the Pro DLQ source headers" do
      before do
        Karafka::Admin.create_topic(source_topic_name, 3, 1)

        PRODUCERS.regular.produce_sync(
          topic: dlq_topic_name,
          partition: 0,
          payload: "failed",
          key: "key",
          headers: {
            "user" => "value",
            "replay_count" => "2",
            "source_topic" => source_topic_name,
            "source_partition" => "2",
            "source_offset" => "7",
            "source_consumer_group" => "cg",
            "source_attempts" => "3",
            "source_trace_id" => "trace"
          }
        )
      end

      let(:source_messages) { Karafka::Admin.read_topic(source_topic_name, 2, 10, 0) }

      it "copies them to their source topic partition with original headers and key" do
        expect(described_class.copy(dlq_topic_name)).to eq(1)

        message = source_messages.first

        expect(source_messages.size).to eq(1)
        expect(message.raw_payload).to eq("failed")
        expect(message.raw_key).to eq("key")
        expect(message.raw_headers).to eq("user" => "value", "replay_count" => "3")
      end

      it "copies them to the target topic when given" do
        expect(described_class.copy(dlq_topic_name, target_topic_name: target_topic_name))
          .to eq(1)

        expect(target_messages.map(&:raw_key)).to eq(%w[key])
        expect(target_messages.first.raw_headers).to eq("user" => "value", "replay_count" => "3")
        expect(source_messages).to be_empty
      end
    end

    context "when no target is given and a message has no source topic header" do
      before do
        PRODUCERS.regular.produce_sync(topic: dlq_topic_name, partition: 0, payload: "failed")
      end

      it "raises naming the message" do
        expect { described_class.copy(dlq_topic_name) }.to raise_error(
          Karafka::Pro::Admin::DeadLetterQueues::Errors::SourceTopicMissingError,
          "#{dlq_topic_name}/0/0"
        )
      end
    end

    context "when a custom producer is given" do
      let(:producer) { PRODUCERS.transactional }

      before do
        PRODUCERS.regular.produce_sync(topic: dlq_topic_name, partition: 0, payload: "0")
        allow(producer).to receive(:produce_many_sync).and_call_original
        allow(Karafka.producer).to receive(:produce_many_sync).and_call_original
      end

      it "dispatches with it" do
        described_class.copy(
          dlq_topic_name,
          target_topic_name: target_topic_name,
          producer: producer
        )

        expect(producer).to have_received(:produce_many_sync)
        expect(Karafka.producer).not_to have_received(:produce_many_sync)
        expect(target_messages.map(&:raw_payload)).to eq(%w[0])
      end
    end
  end
end
