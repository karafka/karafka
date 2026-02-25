# frozen_string_literal: true

RSpec.describe_current do
  subject(:deserializer) { described_class.new }

  let(:job) do
    instance_double(
      ActiveJob::Base,
      serialize: {
        "job_class" => "TestJob",
        "job_id" => "123",
        "arguments" => [1, 2, "test"]
      }
    )
  end

  let(:job_hash) do
    {
      "job_class" => "TestJob",
      "job_id" => "123",
      "arguments" => [1, 2, "test"]
    }
  end

  describe "#serialize" do
    it "serializes the job to JSON" do
      result = deserializer.serialize(job)
      expect(result).to be_a(String)
      parsed = JSON.parse(result)
      expect(parsed["job_class"]).to eq("TestJob")
      expect(parsed["job_id"]).to eq("123")
      expect(parsed["arguments"]).to eq([1, 2, "test"])
    end

    it "returns a valid JSON string" do
      result = deserializer.serialize(job)
      expect { JSON.parse(result) }.not_to raise_error
    end
  end

  describe "#deserialize" do
    let(:raw_payload) { ActiveSupport::JSON.encode(job_hash) }
    let(:message) { instance_double(Karafka::Messages::Message, raw_payload: raw_payload) }

    it "deserializes the message payload into a job hash" do
      result = deserializer.deserialize(message)
      expect(result).to be_a(Hash)
      expect(result["job_class"]).to eq("TestJob")
      expect(result["job_id"]).to eq("123")
      expect(result["arguments"]).to eq([1, 2, "test"])
    end

    it "returns the same structure as the input job hash" do
      result = deserializer.deserialize(message)
      expect(result).to eq(job_hash)
    end
  end

  describe "round-trip serialization" do
    let(:raw_payload) { deserializer.serialize(job) }
    let(:message) { instance_double(Karafka::Messages::Message, raw_payload: raw_payload) }

    it "preserves job data through serialize and deserialize cycle" do
      serialized = deserializer.serialize(job)
      message = instance_double(Karafka::Messages::Message, raw_payload: serialized)
      deserialized = deserializer.deserialize(message)

      expect(deserialized["job_class"]).to eq("TestJob")
      expect(deserialized["job_id"]).to eq("123")
      expect(deserialized["arguments"]).to eq([1, 2, "test"])
    end
  end
end
