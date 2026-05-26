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

  describe "#batch_poll" do
    let(:kafka) { instance_double(Rdkafka::Consumer) }
    let(:max_wait_time) { 1_000 }
    let(:max_messages) { 100 }

    before do
      allow(client).to receive(:kafka).and_return(kafka)
      allow(client).to receive(:events_poll)
      allow(client).to receive(:tick_interval).and_return(100)
      allow(client).to receive(:running?).and_return(true)
      allow(client).to receive(:interval_runner).and_return(-> { :run })
      allow(kafka).to receive(:events_poll)
      allow(subscription_group).to receive(:max_wait_time).and_return(max_wait_time)
      allow(subscription_group).to receive(:max_messages).and_return(max_messages)
    end

    def make_error(code_int, fatal: false)
      Rdkafka::RdkafkaError.new(code_int, fatal: fatal)
    end

    context "when poll_batch returns only messages" do
      let(:message) { instance_double(Rdkafka::Consumer::Message, topic: "test", partition: 0) }

      before do
        allow(kafka).to receive(:poll_batch).and_return([message], [])
      end

      it "adds messages to the buffer and resets the error tracker" do
        tracker = client.instance_variable_get(:@consecutive_errors_tracker)
        tracker.instance_variable_set(:@count, 5)
        client.batch_poll
        expect(tracker.instance_variable_get(:@count)).to eq(0)
      end
    end

    context "when poll_batch returns :partition_eof" do
      let(:eof_error) { make_error(-191) }

      before do
        allow(eof_error).to receive(:details).and_return({ topic: "test", partition: 0 })
        allow(kafka).to receive(:poll_batch).and_return([eof_error])
      end

      it "marks the buffer partition as EOF without raising" do
        expect { client.batch_poll }.not_to raise_error
        expect(client.instance_variable_get(:@buffer).eof?).to be(true)
      end
    end

    context "when poll_batch returns :unknown_topic_or_part with auto-create off" do
      let(:error) { make_error(3) }
      let(:kafka_config) { { "allow.auto.create.topics": false } }

      before do
        allow(subscription_group).to receive(:kafka).and_return(kafka_config)
        allow(kafka).to receive(:poll_batch).and_return([error])
      end

      it "instruments the error without raising and without feeding the safety valve" do
        tracker = client.instance_variable_get(:@consecutive_errors_tracker)
        expect { client.batch_poll }.not_to raise_error
        expect(tracker.instance_variable_get(:@count)).to eq(0)
      end
    end

    context "when poll_batch returns :unknown_topic_or_part with auto-create on" do
      let(:error) { make_error(3) }
      let(:kafka_config) { { "allow.auto.create.topics": true } }

      before do
        allow(subscription_group).to receive(:kafka).and_return(kafka_config)
        allow(kafka).to receive(:poll_batch).and_return([error])
      end

      it "silently skips the error without incrementing the error tracker" do
        tracker = client.instance_variable_get(:@consecutive_errors_tracker)
        expect { client.batch_poll }.not_to raise_error
        expect(tracker.instance_variable_get(:@count)).to eq(0)
      end
    end

    context "when poll_batch returns an EARLY_REPORT_ERROR" do
      let(:error) { make_error(-195) } # :transport

      before do
        allow(kafka).to receive(:poll_batch).and_return([error])
      end

      it "does not raise and does not feed the error tracker" do
        tracker = client.instance_variable_get(:@consecutive_errors_tracker)
        expect { client.batch_poll }.not_to raise_error
        expect(tracker.instance_variable_get(:@count)).to eq(0)
      end
    end

    context "when poll_batch returns a fatal EARLY_REPORT_ERROR (e.g., unreleased_instance_id)" do
      let(:error) { make_error(111, fatal: true) } # :unreleased_instance_id, fatal

      before do
        allow(kafka).to receive(:poll_batch).and_return([error])
        allow(kafka).to receive(:poll).and_return(nil)
      end

      it "does not raise immediately but takes the graceful_break path" do
        expect { client.batch_poll }.not_to raise_error
      end
    end

    context "when poll_batch returns a non-fatal transient error" do
      let(:error) { make_error(-1) } # :unknown, non-fatal

      before do
        allow(kafka).to receive(:poll_batch).and_return([error])
      end

      it "instruments without raising and increments the error tracker" do
        tracker = client.instance_variable_get(:@consecutive_errors_tracker)
        expect { client.batch_poll }.not_to raise_error
        expect(tracker.instance_variable_get(:@count)).to eq(1)
      end

      it "raises after MAX_POLL_RETRIES consecutive error-only batches" do
        tracker = client.instance_variable_get(:@consecutive_errors_tracker)
        tracker.instance_variable_set(:@count, 19)
        expect { client.batch_poll }.to raise_error(Rdkafka::RdkafkaError)
      end

      it "resets the tracker when a subsequent batch delivers messages" do
        tracker = client.instance_variable_get(:@consecutive_errors_tracker)
        tracker.instance_variable_set(:@count, 10)
        message = instance_double(Rdkafka::Consumer::Message, topic: "test", partition: 0)
        allow(kafka).to receive(:poll_batch).and_return([message])
        client.batch_poll
        expect(tracker.instance_variable_get(:@count)).to eq(0)
      end
    end

    context "when poll_batch returns a fatal non-EARLY error" do
      let(:error) { make_error(-1, fatal: true) }

      before do
        allow(kafka).to receive(:poll_batch).and_return([error])
      end

      it "raises immediately" do
        expect { client.batch_poll }.to raise_error(Rdkafka::RdkafkaError)
      end
    end
  end
end
