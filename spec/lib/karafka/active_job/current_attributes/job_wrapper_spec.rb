# frozen_string_literal: true

require "karafka/active_job/current_attributes"

RSpec.describe Karafka::ActiveJob::CurrentAttributes::JobWrapper do
  subject(:wrapper) { described_class.new(job_hash) }

  let(:job_hash) do
    {
      "job_class" => "SomeJob",
      "job_id" => "12345",
      "arguments" => [1, 2, 3],
      "queue_name" => "default",
      "cattr_0" => { "user_id" => 123 },
      "cattr_1" => { "request_id" => "abc-def" }
    }
  end

  describe "#initialize" do
    it "stores the job hash" do
      expect(wrapper.instance_variable_get(:@job_hash)).to eq(job_hash)
    end
  end

  describe "#serialize" do
    it "returns the job hash unchanged" do
      expect(wrapper.serialize).to eq(job_hash)
    end

    it "returns the same object instance" do
      expect(wrapper.serialize).to be(job_hash)
    end

    it "includes current attributes in the hash" do
      result = wrapper.serialize
      expect(result["cattr_0"]).to eq("user_id" => 123)
      expect(result["cattr_1"]).to eq("request_id" => "abc-def")
    end

    context "when called multiple times" do
      it "returns the same hash each time" do
        first_result = wrapper.serialize
        second_result = wrapper.serialize

        expect(first_result).to eq(second_result)
        expect(first_result).to be(second_result)
      end
    end
  end

  describe "thread safety" do
    it "can be used from multiple threads without issues" do
      results = []
      mutex = Mutex.new

      threads = Array.new(10) do |i|
        Thread.new do
          local_hash = job_hash.merge("thread_id" => i)
          local_wrapper = described_class.new(local_hash)
          result = local_wrapper.serialize

          mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(10)
      expect(results.map { |r| r["thread_id"] }.sort).to eq((0..9).to_a)
    end
  end

  describe "minimal interface" do
    it "only implements the serialize method" do
      public_methods = wrapper.public_methods(false)
      expect(public_methods).to contain_exactly(:serialize)
    end
  end
end
