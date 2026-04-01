# frozen_string_literal: true

RSpec.describe_current do
  subject(:pool) { described_class.instance }

  before { pool.reset! }

  describe "#initialize" do
    it "starts with size 0" do
      expect(pool.size).to eq(0)
    end

    it "starts not started" do
      expect(pool.started?).to be(false)
    end
  end

  describe "#reset!" do
    it "resets size to 0" do
      pool.reset!
      expect(pool.size).to eq(0)
    end

    it "resets started? to false" do
      pool.reset!
      expect(pool.started?).to be(false)
    end
  end

  describe "#started?" do
    context "when pool is not started" do
      it "returns false" do
        expect(pool.started?).to be(false)
      end
    end

    if RUBY_VERSION >= "4.0"
      context "when pool is started" do
        before { pool.start(2, min_payloads: 50) }

        it "returns true" do
          expect(pool.started?).to be(true)
        end
      end
    end
  end

  describe "#size" do
    it "returns 0 when not started" do
      expect(pool.size).to eq(0)
    end

    if RUBY_VERSION >= "4.0"
      context "when pool is started" do
        before { pool.start(2, min_payloads: 50) }

        it "returns the configured concurrency" do
          expect(pool.size).to eq(2)
        end
      end
    end
  end

  if RUBY_VERSION >= "4.0"
    describe "#start" do
      it "sets the pool as started" do
        pool.start(2, min_payloads: 50)
        expect(pool.started?).to be(true)
      end

      it "sets the pool size" do
        pool.start(3, min_payloads: 50)
        expect(pool.size).to eq(3)
      end

      it "is idempotent" do
        pool.start(2, min_payloads: 50)
        pool.start(4, min_payloads: 100)
        expect(pool.size).to eq(2)
      end
    end
  end

  describe "#dispatch_async" do
    let(:deserializer) do
      Class.new do
        def call(message)
        end
      end.new
    end
    let(:distributor) { Karafka::Deserializing::Parallel::Distributor.new }
    let(:messages) do
      Array.new(10) do |i|
        instance_double(
          Karafka::Messages::Message,
          raw_payload: "payload_#{i}" * 100
        )
      end
    end

    context "when messages array is empty" do
      it "returns Immediate" do
        result = pool.dispatch_async([], deserializer, distributor)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    context "when pool is not started" do
      it "returns Immediate" do
        result = pool.dispatch_async(messages, deserializer, distributor)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    context "when messages count is below min_payloads threshold" do
      let(:messages) do
        Array.new(5) do |i|
          instance_double(
            Karafka::Messages::Message,
            raw_payload: "payload_#{i}"
          )
        end
      end

      it "returns Immediate for inline deserialization" do
        result = pool.dispatch_async(messages, deserializer, distributor)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    if RUBY_VERSION >= "4.0"
      context "when pool is started and batch meets threshold" do
        let(:deserializer) do
          Class.new do
            def call(message)
              message.raw_payload.upcase
            end
          end.new.freeze
        end

        let(:messages) do
          Array.new(100) do |i|
            instance_double(
              Karafka::Messages::Message,
              raw_payload: "payload_#{i}"
            )
          end
        end

        before { pool.start(2, min_payloads: 50) }

        it "returns a Future" do
          result = pool.dispatch_async(messages, deserializer, distributor)
          expect(result).to be_a(Karafka::Deserializing::Parallel::Future)
        end

        it "dispatches work that can be retrieved" do
          result = pool.dispatch_async(messages, deserializer, distributor)
          deserialized = result.retrieve
          expect(deserialized.size).to eq(100)
          expect(deserialized.first).to eq("PAYLOAD_0")
        end
      end
    end
  end
end
