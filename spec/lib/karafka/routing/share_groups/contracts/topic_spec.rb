# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      id: "id",
      name: "name",
      active: true,
      consumer: Class.new(Karafka::ShareConsumer),
      deserializers: {},
      kafka: { "bootstrap.servers": "localhost:9092" },
      max_messages: 10,
      max_wait_time: 10_000,
      subscription_group_details: {
        name: SecureRandom.hex(6)
      }
    }
  end

  context "when config is valid" do
    it { expect(check).to be_success }
  end

  context "when we validate name" do
    context "when it has an invalid second line" do
      before { config[:name] = "ok\nbad name!" }

      it { expect(check).not_to be_success }
    end

    context "when it is a dot" do
      before { config[:name] = "." }

      it { expect(check).not_to be_success }
    end

    context "when it is longer than 249 characters" do
      before { config[:name] = "a" * 250 }

      it { expect(check).not_to be_success }
    end
  end

  context "when we validate consumer" do
    context "when topic is not active" do
      before do
        config[:consumer] = nil
        config[:active] = false
      end

      it "expect not to require consumer" do
        expect(check).to be_success
      end
    end

    context "when it is a by-name String reference" do
      before { config[:consumer] = "SomeConsumerByName" }

      it { expect(check).to be_success }
    end

    context "when it is a share consumer instance" do
      before { config[:consumer] = Class.new(Karafka::ShareConsumer).new }

      it "expect not to be valid with a class-required error" do
        expect(check).not_to be_success
        expect(check.errors.to_h[:consumer]).to include("consumer class or its name")
      end
    end

    context "when it is an Integer" do
      before { config[:consumer] = 123 }

      it { expect(check).not_to be_success }
    end
  end
end
