# frozen_string_literal: true

RSpec.describe_current do
  subject(:create_topics) { described_class.new }

  describe "#call" do
    let(:declaratives_routing_topics) { [double, double] }
    let(:existing_topics_names) { ["existing_topic"] }

    before do
      allow(create_topics).to receive_messages(
        declaratives_routing_topics: declaratives_routing_topics,
        existing_topics_names: existing_topics_names,
        # Suppress console output
        puts: nil
      )

      declaratives_routing_topics.each_with_index do |topic, index|
        declaratives = instance_double(
          Karafka::Declaratives::Topic,
          partitions: 1,
          replication_factor: 1,
          details: {}
        )

        allow(topic).to receive_messages(
          name: "topic_#{index}",
          declaratives: declaratives
        )
      end

      allow(Karafka::Admin).to receive(:create_topic)
    end

    context "when all topics already exist" do
      before do
        allow(create_topics)
          .to receive(:existing_topics_names)
          .and_return(%w[topic_0 topic_1])
      end

      it "does not create any topics and returns false" do
        expect(create_topics.call).to be_falsey
        expect(Karafka::Admin).not_to have_received(:create_topic)
      end
    end

    context "when some topics do not exist" do
      it "creates only the non-existing topics and returns true" do
        expect(create_topics.call).to be_truthy

        expect(Karafka::Admin).to have_received(:create_topic).with(
          "topic_1",
          anything,
          anything,
          anything
        ).once
      end
    end

    context "when no topics exist" do
      let(:existing_topics_names) { [] }

      it "creates all topics and returns true" do
        expect(create_topics.call).to be_truthy

        expect(Karafka::Admin).to have_received(:create_topic).twice
      end
    end

    context "when a topic has configuration unknown to the cluster" do
      before do
        allow(create_topics)
          .to receive(:unknown_configs)
          .and_return(declaratives_routing_topics[1] => { "retention.msx" => "1" })
      end

      it "raises and does not create any topics" do
        expect { create_topics.call }.to raise_error(Karafka::Errors::CommandValidationError)
        expect(Karafka::Admin).not_to have_received(:create_topic)
      end
    end

    context "when describing a declared topic configuration is not allowed" do
      let(:existing_topics_names) { %w[topic_0] }
      let(:error) { Rdkafka::RdkafkaError.new(Rdkafka::Bindings::RD_KAFKA_RESP_ERR__FATAL) }

      before do
        allow(declaratives_routing_topics[0].declaratives)
          .to receive(:details)
          .and_return("retention.ms": 1)
        allow(error).to receive(:code).and_return(:topic_authorization_failed)
        allow(Karafka::Admin::Configs).to receive(:describe).and_raise(error)
      end

      it "raises a validation error and does not create any topics" do
        expect { create_topics.call }.to raise_error(Karafka::Errors::CommandValidationError)
        expect(Karafka::Admin).not_to have_received(:create_topic)
      end
    end
  end
end
