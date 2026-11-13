# frozen_string_literal: true

RSpec.describe_current do
  subject(:client) { described_class.new(subscription_group, -> { true }) }

  let(:subscription_group) { build(:routing_subscription_group) }

  describe "#name" do
    let(:client_id) { SecureRandom.hex(6) }
    let(:start_nr) { client.name.split("-").last.to_i }

    before do
      Karafka::App.config.client_id = client_id
      client.send(:kafka)
    end

    after do
      client.stop
      client.send(:kafka).close
    end

    # Kafka counts all the consumers one after another, that is why we need to check it in one
    # spec
    it "expect to give it proper names within the lifecycle" do
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr}")
      client.reset
      client.send(:kafka)
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr + 1}")
      client.stop
      client.send(:kafka)
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr + 2}")
    end
  end

  describe "#assignment" do
    let(:kafka) { instance_double(Rdkafka::Consumer) }

    before do
      allow(client).to receive(:kafka).and_return(kafka)
      allow(kafka).to receive(:assignment)
    end

    it "expect to delegate to client" do
      client.assignment

      expect(kafka).to have_received(:assignment)
    end
  end

  describe "#assignment_lost?" do
    let(:kafka) { instance_double(Rdkafka::Consumer) }

    before do
      allow(client).to receive(:kafka).and_return(kafka)
      allow(kafka).to receive(:assignment_lost?)
    end

    it "expect to delegate to client" do
      client.assignment_lost?

      expect(kafka).to have_received(:assignment_lost?)
    end
  end

  describe "#query_watermark_offsets" do
    let(:topic) { "test_topic" }
    let(:partition) { 0 }
    let(:watermark_offsets) { [100, 200] }
    let(:kafka) { instance_double(Rdkafka::Consumer) }

    before do
      allow(client).to receive(:build_consumer).and_return(kafka)
      allow(kafka).to receive_messages(
        start: nil,
        name: "test-consumer",
        query_watermark_offsets: watermark_offsets
      )

      client.send(:kafka)
    end

    it "expect to delegate to wrapped kafka" do
      result = client.query_watermark_offsets(topic, partition)
      expect(result).to eq(watermark_offsets)
    end
  end

  describe "#read_partition_offsets" do
    let(:specs) { { "test_topic" => [{ partition: 0, offset: :latest }] } }
    let(:offsets) { [{ topic: "test_topic", partition: 0, offset: 10 }] }
    let(:kafka) { instance_double(Rdkafka::Consumer) }
    let(:handle) { instance_double(Rdkafka::Admin::ListOffsetsHandle) }
    let(:report) { instance_double(Rdkafka::Admin::ListOffsetsReport, offsets: offsets) }

    before do
      allow(client).to receive(:build_consumer).and_return(kafka)
      allow(kafka).to receive_messages(
        start: nil,
        name: "test-consumer",
        list_offsets: handle
      )
      allow(handle).to receive(:wait).and_return(report)

      client.send(:kafka)
    end

    it "expect to return the resolved offsets" do
      expect(client.read_partition_offsets(specs)).to eq(offsets)
    end

    context "when the isolation level is not configured" do
      it "expect to resolve them with the librdkafka default of read_committed" do
        client.read_partition_offsets(specs)

        expect(kafka)
          .to have_received(:list_offsets)
          .with(specs, isolation_level: Karafka::Admin::IsolationLevels::READ_COMMITTED)
      end
    end

    context "when the consumer reads uncommitted" do
      let(:subscription_group) do
        build(:routing_subscription_group).tap do |sub_group|
          allow(sub_group)
            .to receive(:kafka)
            .and_return(sub_group.kafka.merge("isolation.level": "read_uncommitted"))
        end
      end

      it "expect to resolve them with the read_uncommitted level" do
        client.read_partition_offsets(specs)

        expect(kafka)
          .to have_received(:list_offsets)
          .with(specs, isolation_level: Karafka::Admin::IsolationLevels::READ_UNCOMMITTED)
      end
    end
  end

  describe "#events_poll" do
    let(:kafka) { instance_double(Rdkafka::Consumer) }

    before do
      allow(client).to receive(:kafka).and_return(kafka)
    end

    context "when safe is false and rdkafka raises" do
      before do
        allow(kafka).to receive(:events_poll).and_raise(Rdkafka::RdkafkaError.new(0))
      end

      it "expect to raise the error" do
        expect { client.events_poll }.to raise_error(Rdkafka::RdkafkaError)
      end
    end

    context "when safe is true and rdkafka raises" do
      before do
        allow(kafka).to receive(:events_poll).and_raise(Rdkafka::RdkafkaError.new(0))
      end

      it "expect to swallow the error" do
        expect { client.events_poll(safe: true) }.not_to raise_error
      end

      it "expect to return nil" do
        expect(client.events_poll(safe: true)).to be_nil
      end
    end

    context "when no error occurs" do
      before do
        allow(kafka).to receive(:events_poll)
      end

      it "expect to instrument the event" do
        expect(Karafka.monitor).to receive(:instrument).with(
          "client.events_poll",
          caller: client,
          subscription_group: subscription_group
        )

        client.events_poll
      end
    end
  end

  describe "#batch_poll" do
    let(:kafka) { instance_double(Rdkafka::Consumer, events_poll: nil) }
    let(:topic_name) { SecureRandom.hex(6) }
    let(:error) { Rdkafka::RdkafkaError.new(3, details: { topic: topic_name }) }

    before do
      allow(client).to receive(:kafka).and_return(kafka)
      allow(subscription_group).to receive(:max_wait_time).and_return(100)
      allow(kafka).to receive(:poll).and_raise(error)
      allow(Karafka.monitor).to receive(:instrument).and_call_original
    end

    [true, "true"].each do |auto_create|
      context "when subscribed topic does not exist and auto creation is #{auto_create.inspect}" do
        before do
          allow(subscription_group).to receive(:kafka)
            .and_return(subscription_group.kafka.merge("allow.auto.create.topics": auto_create))

          client.batch_poll
        end

        it "expect to instrument the unknown topic event" do
          expect(Karafka.monitor).to have_received(:instrument).with(
            "client.topics.unknown",
            caller: client,
            subscription_group: subscription_group,
            topic: topic_name,
            error: error
          ).at_least(:once)
        end

        it "expect not to report it as an error" do
          expect(Karafka.monitor).not_to have_received(:instrument).with("error.occurred", any_args)
        end
      end
    end

    context "when subscribed topic does not exist and auto creation is false" do
      before do
        allow(subscription_group).to receive(:kafka)
          .and_return(subscription_group.kafka.merge("allow.auto.create.topics": false))

        # Not running, so the error is not retried
        client.batch_poll
      rescue Rdkafka::RdkafkaError
        nil
      end

      it "expect to raise the error" do
        expect { client.batch_poll }.to raise_error(error)
      end

      it "expect not to instrument the unknown topic event" do
        expect(Karafka.monitor)
          .not_to have_received(:instrument).with("client.topics.unknown", any_args)
      end

      it "expect to report it as an error" do
        expect(Karafka.monitor).to have_received(:instrument).with(
          "error.occurred",
          caller: client,
          error: error,
          type: "connection.client.poll.error"
        ).at_least(:once)
      end
    end

    context "when a message fails to build" do
      let(:error) { Rdkafka::RdkafkaError.new(-199, "Error reading message headers") }

      before do
        # Enough time to retry, so it is reported even when it is not raised
        allow(subscription_group).to receive(:max_wait_time).and_return(1_000)
        allow(kafka).to receive(:poll).and_invoke(->(_) { raise error }, ->(_) {})

        client.batch_poll
      end

      it "expect to report it as an error" do
        expect(Karafka.monitor).to have_received(:instrument).with(
          "error.occurred",
          caller: client,
          error: error,
          type: "connection.client.poll.error"
        )
      end
    end

    context "when the poll error action is not supported" do
      before { allow(client).to receive(:poll_error_action).and_return(:unsupported) }

      it "expect to raise the unsupported case error" do
        expect { client.batch_poll }.to raise_error(Karafka::Errors::UnsupportedCaseError)
      end
    end
  end

  describe "#batch_poll draining of prefetched messages" do
    let(:kafka) { instance_double(Rdkafka::Consumer, events_poll: nil) }
    let(:topic_name) { SecureRandom.hex(6) }
    let(:max_messages) { 100 }
    let(:first) { build(:kafka_fetched_message, topic: topic_name, partition: 0, offset: 0) }
    let(:drained) { [] }

    let(:buffer_state) do
      state = {}
      client.batch_poll.each do |topic, partition, messages, eof|
        state[[topic, partition]] = { offsets: messages.map(&:offset), eof: eof }
      end
      state
    end

    def message(partition, offset)
      build(:kafka_fetched_message, topic: topic_name, partition: partition, offset: offset)
    end

    def eof_error(partition, offset)
      Rdkafka::RdkafkaError.new(
        -191,
        details: { topic: topic_name, partition: partition, offset: offset }
      )
    end

    before do
      allow(client).to receive(:kafka).and_return(kafka)
      allow(subscription_group).to receive_messages(max_wait_time: 100, max_messages: max_messages)
      allow(kafka).to receive(:poll).and_return(first, nil)
      allow(kafka).to receive(:poll_batch_nb).and_return(drained)
      allow(Karafka.monitor).to receive(:instrument).and_call_original
    end

    context "when only messages are ready" do
      let(:drained) { [message(0, 1), message(0, 2)] }

      it "expect to drain them into the buffer after the first message" do
        expect(buffer_state).to eq([topic_name, 0] => { offsets: [0, 1, 2], eof: false })
      end

      it "expect to drain without waiting and only as much as there is room for" do
        client.batch_poll
        expect(kafka).to have_received(:poll_batch_nb).with(0, max_items: 99)
      end
    end

    context "when the first message fills the buffer" do
      let(:max_messages) { 1 }

      it "expect not to drain" do
        client.batch_poll
        expect(kafka).not_to have_received(:poll_batch_nb)
      end
    end

    context "when nothing was polled" do
      before { allow(kafka).to receive(:poll).and_return(nil) }

      it "expect not to drain" do
        client.batch_poll
        expect(kafka).not_to have_received(:poll_batch_nb)
      end
    end

    context "when partition eof is in the middle of the drain" do
      let(:drained) { [message(0, 1), eof_error(0, 2), message(1, 0)] }

      it "expect to keep all the messages and mark the eof" do
        expect(buffer_state).to eq(
          [topic_name, 0] => { offsets: [0, 1], eof: true },
          [topic_name, 1] => { offsets: [0], eof: false }
        )
      end

      it "expect to finish the batch after the drain" do
        client.batch_poll
        expect(kafka).to have_received(:poll).once
      end
    end

    context "when a message of the same partition comes after its eof" do
      let(:drained) { [eof_error(0, 1), message(0, 1)] }

      it "expect not to mark the partition as eof" do
        expect(buffer_state).to eq([topic_name, 0] => { offsets: [0, 1], eof: false })
      end

      it "expect to continue polling" do
        client.batch_poll
        expect(kafka).to have_received(:poll).twice
      end
    end

    context "when the blocking poll returns an eof" do
      let(:drained) { [eof_error(1, 0), message(2, 0), eof_error(2, 1)] }

      before { allow(kafka).to receive(:poll).and_raise(eof_error(0, 0)) }

      it "expect to drain the eof events of other partitions into the same batch" do
        expect(buffer_state).to eq(
          [topic_name, 0] => { offsets: [], eof: true },
          [topic_name, 1] => { offsets: [], eof: true },
          [topic_name, 2] => { offsets: [0], eof: true }
        )
      end

      it "expect to drain without waiting and to finish the batch after the drain" do
        client.batch_poll
        expect(kafka).to have_received(:poll_batch_nb).with(0, max_items: 100)
        expect(kafka).to have_received(:poll).once
      end

      context "when the assignment changed during that poll" do
        let(:assignment) do
          {
            subscription_group_id: subscription_group.id,
            tpl: Rdkafka::Consumer::TopicPartitionList.new(
              topic_name => [Rdkafka::Consumer::Partition.new(0, nil)]
            )
          }
        end

        before do
          allow(kafka).to receive(:poll) do
            client.rebalance_manager.on_rebalance_partitions_assigned(assignment)
            raise eof_error(0, 0)
          end
        end

        it "expect not to drain" do
          client.batch_poll
          expect(kafka).not_to have_received(:poll_batch_nb)
        end
      end
    end

    context "when many partitions reach eof in one drain" do
      let(:drained) { [message(1, 0), eof_error(0, 1), eof_error(1, 1)] }

      it "expect to mark all of them" do
        expect(buffer_state).to eq(
          [topic_name, 0] => { offsets: [0], eof: true },
          [topic_name, 1] => { offsets: [0], eof: true }
        )
      end
    end

    context "when there is no eof in the drain" do
      let(:drained) { [message(0, 1)] }

      it "expect to continue polling" do
        client.batch_poll
        expect(kafka).to have_received(:poll).twice
      end
    end

    context "when the drain has an unknown topic error and auto creation is on" do
      let(:error) { Rdkafka::RdkafkaError.new(3, details: { topic: topic_name }) }
      let(:drained) { [error, message(0, 1)] }

      before do
        allow(subscription_group).to receive(:kafka)
          .and_return(subscription_group.kafka.merge("allow.auto.create.topics": true))
      end

      it "expect to keep the messages after it" do
        expect(buffer_state).to eq([topic_name, 0] => { offsets: [0, 1], eof: false })
      end

      it "expect to instrument the unknown topic event" do
        client.batch_poll

        expect(Karafka.monitor).to have_received(:instrument).with(
          "client.topics.unknown",
          caller: client,
          subscription_group: subscription_group,
          topic: topic_name,
          error: error
        )
      end

      it "expect not to report it as an error" do
        client.batch_poll
        expect(Karafka.monitor).not_to have_received(:instrument).with("error.occurred", any_args)
      end
    end

    context "when the drain has an early reported error" do
      let(:error) { Rdkafka::RdkafkaError.new(-147) }
      let(:drained) { [error, message(0, 1)] }

      it "expect to keep the messages after it" do
        expect(buffer_state).to eq([topic_name, 0] => { offsets: [0, 1], eof: false })
      end

      it "expect to report it as an error" do
        client.batch_poll

        expect(Karafka.monitor).to have_received(:instrument).with(
          "error.occurred",
          caller: client,
          error: error,
          type: "connection.client.poll.error"
        )
      end
    end

    context "when the drain has a retryable error that is not early reported" do
      let(:error) { Rdkafka::RdkafkaError.new(-185) }
      let(:drained) { [error, message(0, 1)] }

      it "expect to keep the messages after it" do
        expect(buffer_state).to eq([topic_name, 0] => { offsets: [0, 1], eof: false })
      end

      it "expect not to report it as on the first attempt of a blocking poll" do
        client.batch_poll
        expect(Karafka.monitor).not_to have_received(:instrument).with("error.occurred", any_args)
      end
    end

    context "when the drain has a message that failed to build" do
      let(:error) { Rdkafka::RdkafkaError.new(-199, "Error reading message headers") }
      let(:drained) { [message(0, 1), error, message(0, 3)] }

      it "expect to keep the messages around it" do
        expect(buffer_state).to eq([topic_name, 0] => { offsets: [0, 1, 3], eof: false })
      end

      it "expect to report it" do
        client.batch_poll

        expect(Karafka.monitor).to have_received(:instrument).with(
          "error.occurred",
          caller: client,
          error: error,
          type: "connection.client.poll.error"
        )
      end
    end

    context "when a partition is revoked and assigned back inside of the drain" do
      let(:drained) { [message(0, 1), message(0, 2), message(1, 0)] }

      let(:tpl) do
        {
          subscription_group_id: subscription_group.id,
          tpl: Rdkafka::Consumer::TopicPartitionList.new(
            topic_name => [Rdkafka::Consumer::Partition.new(0, nil)]
          )
        }
      end

      let(:position) { 3 }

      before do
        allow(kafka).to receive(:seek)
        allow(kafka).to receive(:position) do
          Rdkafka::Consumer::TopicPartitionList.new(
            topic_name => [Rdkafka::Consumer::Partition.new(0, position)]
          )
        end
        allow(kafka).to receive(:poll_batch_nb) do
          client.rebalance_manager.on_rebalance_partitions_revoked(tpl)
          client.rebalance_manager.on_rebalance_partitions_assigned(tpl)
          drained
        end
      end

      it "expect to remove its drained messages" do
        expect(buffer_state).to eq([topic_name, 1] => { offsets: [0], eof: false })
      end

      it "expect to seek it back to the first of them" do
        client.batch_poll

        expect(kafka).to have_received(:seek) do |seek|
          expect([seek.topic, seek.partition, seek.offset]).to eq([topic_name, 0, 1])
        end
      end

      context "when only a message from before the revocation was drained" do
        let(:first) { message(0, 5) }
        let(:drained) { [message(0, 6)] }
        let(:position) { 5 }

        it "expect not to seek forward past the restart point" do
          client.batch_poll
          expect(kafka).not_to have_received(:seek)
        end
      end

      context "when a message from before the revocation precedes lower ones" do
        let(:drained) { [message(0, 6), message(0, 5), message(0, 6)] }
        let(:position) { 7 }

        it "expect to seek back to the lowest drained offset" do
          client.batch_poll

          expect(kafka).to have_received(:seek) do |seek|
            expect([seek.topic, seek.partition, seek.offset]).to eq([topic_name, 0, 5])
          end
        end
      end
    end

    context "when the drain has an error that cannot be retried" do
      let(:error) { Rdkafka::RdkafkaError.new(3, details: { topic: topic_name }) }
      let(:drained) { [message(0, 1), error] }

      before do
        allow(Karafka::App).to receive(:running?).and_return(false)
        allow(subscription_group).to receive(:kafka)
          .and_return(subscription_group.kafka.merge("allow.auto.create.topics": false))
      end

      it "expect to raise it" do
        expect { client.batch_poll }.to raise_error(error)
      end

      it "expect to report it as an error" do
        expect { client.batch_poll }.to raise_error(error)

        expect(Karafka.monitor).to have_received(:instrument).with(
          "error.occurred",
          caller: client,
          error: error,
          type: "connection.client.poll.error"
        )
      end
    end

    context "when the drain error action is not supported" do
      let(:drained) { [message(0, 1), Rdkafka::RdkafkaError.new(-185)] }

      before { allow(client).to receive(:poll_error_action).and_return(:unsupported) }

      it "expect to raise the unsupported case error" do
        expect { client.batch_poll }.to raise_error(Karafka::Errors::UnsupportedCaseError)
      end
    end

    context "when partitions are revoked inside of the drain" do
      let(:drained) { [message(0, 1), message(1, 0), message(1, 0)] }

      let(:revocation) do
        {
          subscription_group_id: subscription_group.id,
          tpl: Rdkafka::Consumer::TopicPartitionList.new(
            topic_name => [Rdkafka::Consumer::Partition.new(0, nil)]
          )
        }
      end

      before do
        allow(kafka).to receive(:poll_batch_nb) do
          client.rebalance_manager.on_rebalance_partitions_revoked(revocation)
          drained
        end
      end

      it "expect to remove the drained messages of the revoked partitions and duplicates" do
        expect(buffer_state).to eq([topic_name, 1] => { offsets: [0], eof: false })
      end
    end

    context "when partitions were revoked and assigned back during the first poll" do
      let(:drained) { [message(0, 1)] }

      let(:assignment) do
        {
          subscription_group_id: subscription_group.id,
          tpl: Rdkafka::Consumer::TopicPartitionList.new(
            topic_name => [Rdkafka::Consumer::Partition.new(0, nil)]
          )
        }
      end

      before do
        allow(kafka).to receive(:poll) do
          client.rebalance_manager.on_rebalance_partitions_revoked(assignment)
          client.rebalance_manager.on_rebalance_partitions_assigned(assignment)
          first
        end
      end

      it "expect to keep the message of the new assignment and not to drain" do
        expect(buffer_state).to eq([topic_name, 0] => { offsets: [0], eof: false })
        expect(kafka).not_to have_received(:poll_batch_nb)
      end
    end
  end

  describe "#reset" do
    let(:kafka) { instance_double(Rdkafka::Consumer) }
    let(:sg_id) { subscription_group.id }
    let(:error_callbacks) do
      Karafka::Core::Instrumentation.error_callbacks.instance_variable_get(:@callbacks)
    end

    before do
      client.instance_variable_set(:@kafka, kafka)
      Karafka::Core::Instrumentation.statistics_callbacks.add(sg_id, -> {})
      Karafka::Core::Instrumentation.error_callbacks.add(sg_id, -> {})
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.add(sg_id, -> {})
    end

    after do
      Karafka::Core::Instrumentation.statistics_callbacks.delete(sg_id)
      Karafka::Core::Instrumentation.error_callbacks.delete(sg_id)
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.delete(sg_id)
    end

    context "when closing the kafka consumer" do
      let(:registered_on_close) { [] }

      before do
        allow(kafka).to receive(:close) { registered_on_close << error_callbacks.key?(sg_id) }
      end

      it "expect to keep the error callback until the consumer is closed" do
        client.reset

        expect(registered_on_close).to eq([true])
      end

      it "expect to remove the error callback after the close" do
        client.reset

        expect(error_callbacks).not_to have_key(sg_id)
      end
    end

    context "when closing the kafka consumer raises" do
      let(:error) { Rdkafka::RdkafkaError.new(Rdkafka::Bindings::RD_KAFKA_RESP_ERR__FATAL) }

      before { allow(kafka).to receive(:close).and_raise(error) }

      it "expect to remove the error callback anyhow" do
        expect { client.reset }.to raise_error(Rdkafka::RdkafkaError)
        expect(error_callbacks).not_to have_key(sg_id)
      end
    end
  end

  describe "#inspect" do
    let(:client_name) { "test-consumer-1" }

    before do
      allow(client).to receive(:name).and_return(client_name)
    end

    context "when client is open" do
      it "expect to show client details with open state" do
        result = client.inspect

        expect(result).to include(described_class.name)
        expect(result).to include("state=open")
      end
    end

    context "when client is closed" do
      before { client.instance_variable_set(:@closed, true) }

      it "expect to show client details with closed state" do
        result = client.inspect

        expect(result).to include("state=closed")
      end
    end

    context "when name is empty" do
      before { allow(client).to receive(:name).and_return("") }

      it "expect to handle empty name gracefully" do
        result = client.inspect

        expect(result).to include('name=""')
      end
    end

    it "expect to not call inspect on complex nested objects" do
      allow(client.instance_variable_get(:@subscription_group)).to receive(:inspect)
      allow(client.instance_variable_get(:@buffer)).to receive(:inspect)
      allow(client.instance_variable_get(:@rebalance_manager)).to receive(:inspect)

      client.inspect

      expect(client.instance_variable_get(:@subscription_group)).not_to have_received(:inspect)
      expect(client.instance_variable_get(:@buffer)).not_to have_received(:inspect)
      expect(client.instance_variable_get(:@rebalance_manager)).not_to have_received(:inspect)
    end

    it "expect to be safe for logging without performance issues" do
      start_time = Time.now
      client.inspect
      end_time = Time.now

      expect(end_time - start_time).to be < 0.01
    end
  end
end
