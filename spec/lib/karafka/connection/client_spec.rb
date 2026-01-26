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
