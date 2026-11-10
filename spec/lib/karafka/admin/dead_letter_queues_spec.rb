# frozen_string_literal: true

RSpec.describe_current do
  let(:dlq_topic_name) { generate_topic_name }
  let(:target_topic_name) { generate_topic_name }
  let(:source_topic_name) { generate_topic_name }

  let(:target_messages) { Karafka::Admin.read_topic(target_topic_name, 0, 100, 0) }

  describe "#copy" do
    before do
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
          Karafka::Errors::SourceTopicMissingError,
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
