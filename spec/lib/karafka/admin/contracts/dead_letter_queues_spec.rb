# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      topic_name: "dlq",
      target_topic_name: nil,
      partitions: nil,
      start_offset: 0,
      end_offset: nil,
      producer: nil,
      custom_kafka: false
    }
  end

  context "when config is valid" do
    it { expect(contract.call(config)).to be_success }
  end

  context "when all the optional values are set" do
    before { config.merge!(target_topic_name: "target", partitions: [0, 2], end_offset: 10) }

    it { expect(contract.call(config)).to be_success }
  end

  context "when start_offset is a time" do
    before { config[:start_offset] = Time.now }

    it { expect(contract.call(config)).to be_success }
  end

  context "when topic_name is missing" do
    before { config.delete(:topic_name) }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when topic_name is empty" do
    before { config[:topic_name] = "" }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when topic_name is a symbol" do
    before { config[:topic_name] = :dlq }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when target_topic_name is empty" do
    before { config[:target_topic_name] = "" }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when partitions is empty" do
    before { config[:partitions] = [] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when partitions contain a negative partition" do
    before { config[:partitions] = [0, -1] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when partitions contain duplicates" do
    before { config[:partitions] = [0, 0] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when kafka is custom and there is no producer" do
    before { config[:custom_kafka] = true }

    it { expect(contract.call(config)).not_to be_success }
    it { expect(contract.call(config).errors).to eq(producer: "producer needs to be provided with a custom kafka configuration") }
  end

  context "when kafka is custom and a producer is given" do
    before { config.merge!(custom_kafka: true, producer: Karafka.producer) }

    it { expect(contract.call(config)).to be_success }
  end

  context "when partitions is not an array" do
    before { config[:partitions] = 0 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when start_offset is negative" do
    before { config[:start_offset] = -1 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when start_offset is nil" do
    before { config[:start_offset] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when end_offset is negative" do
    before { config[:end_offset] = -1 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when end_offset is not an integer" do
    before { config[:end_offset] = "10" }

    it { expect(contract.call(config)).not_to be_success }
  end
end
