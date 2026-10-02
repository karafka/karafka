# frozen_string_literal: true

RSpec.describe_current do
  subject(:injector) { described_class }

  let(:kafka_config) { {} }

  describe "#managed_keys" do
    it "returns a set with managed keys" do
      expect(injector.managed_keys).to be_a(Set)
      expect(injector.managed_keys).not_to be_empty
    end

    it "includes statistics.unassigned.include" do
      expect(injector.managed_keys).to include(:"statistics.unassigned.include")
    end
  end

  describe "scope injectors" do
    it "builds the consumer-group injector on the core Configurable::Injector" do
      expect(described_class::ConsumerGroup.ancestors).to include(
        Karafka::Core::Configurable::Injector
      )
    end

    it "builds the producer injector on the core Configurable::Injector" do
      expect(described_class::Producer.ancestors).to include(
        Karafka::Core::Configurable::Injector
      )
    end

    it "builds the share-group injector on the core Configurable::Injector" do
      expect(described_class::ShareGroup.ancestors).to include(
        Karafka::Core::Configurable::Injector
      )
    end
  end

  describe "#consumer_group vs #consumer legacy alias" do
    let(:via_canonical) { {} }
    let(:via_legacy) { {} }

    it "expect the legacy alias to produce the same defaults as the canonical method" do
      injector.consumer_group(via_canonical)
      injector.consumer(via_legacy)

      expect(via_legacy).to eq(via_canonical)
    end
  end

  describe "#share_group" do
    let(:share_kafka_config) { {} }

    before { injector.share_group(share_kafka_config) }

    it "adds the mode-agnostic defaults" do
      expect(share_kafka_config).to include(
        "statistics.interval.ms": 5_000,
        "client.software.name": "karafka",
        "socket.nagle.disable": true
      )
    end

    it "does not add the consumer-group only max.poll.interval.ms" do
      expect(share_kafka_config).not_to include(:"max.poll.interval.ms")
    end
  end

  describe "#consumer" do
    context "when in production environment" do
      before do
        allow(Karafka::App.env).to receive(:production?).and_return(true)
        injector.consumer(kafka_config)
      end

      it "adds only consumer kafka defaults" do
        expect(kafka_config).to include(
          "statistics.interval.ms": 5_000,
          "client.software.name": "karafka",
          "max.poll.interval.ms": 300_000,
          "socket.nagle.disable": true,
          "client.software.version": [
            "v#{Karafka::VERSION}",
            "rdkafka-ruby-v#{Rdkafka::VERSION}",
            "librdkafka-v#{Rdkafka::LIBRDKAFKA_VERSION}"
          ].join("-")
        )
      end

      it "does not add consumer kafka dev defaults" do
        expect(kafka_config).not_to include(
          "allow.auto.create.topics": "true",
          "topic.metadata.refresh.interval.ms": 5_000
        )
      end
    end

    context "when not in production environment" do
      before do
        allow(Karafka::App.env).to receive(:production?).and_return(false)
        injector.consumer(kafka_config)
      end

      it "adds both consumer kafka defaults and dev defaults" do
        expect(kafka_config).to include(
          "statistics.interval.ms": 5_000,
          "client.software.name": "karafka",
          "max.poll.interval.ms": 300_000,
          "socket.nagle.disable": true,
          "client.software.version": [
            "v#{Karafka::VERSION}",
            "rdkafka-ruby-v#{Rdkafka::VERSION}",
            "librdkafka-v#{Rdkafka::LIBRDKAFKA_VERSION}"
          ].join("-"),
          "allow.auto.create.topics": "true",
          "topic.metadata.refresh.interval.ms": 5_000
        )
      end
    end

    context "when defaults are already present in kafka_config" do
      let(:kafka_config) do
        {
          "statistics.interval.ms": 10_000,
          "client.software.name": "custom_name",
          "max.poll.interval.ms": 200_000,
          "client.software.version": "custom_version",
          "allow.auto.create.topics": "false",
          "topic.metadata.refresh.interval.ms": 10_000
        }
      end

      before do
        allow(Karafka::App.env).to receive(:production?).and_return(false)
        injector.consumer(kafka_config)
      end

      it "does not overwrite existing settings" do
        expect(kafka_config).to eq(
          "statistics.interval.ms": 10_000,
          "client.software.name": "custom_name",
          "max.poll.interval.ms": 200_000,
          "client.software.version": "custom_version",
          "allow.auto.create.topics": "false",
          "topic.metadata.refresh.interval.ms": 10_000,
          "socket.nagle.disable": true
        )
      end
    end
  end

  describe "#producer" do
    context "when in production environment" do
      before do
        allow(Karafka::App.env).to receive(:production?).and_return(true)
        injector.producer(kafka_config)
      end

      it "does not add any producer kafka defaults" do
        expect(kafka_config).to be_empty
      end
    end

    context "when not in production environment" do
      before do
        allow(Karafka::App.env).to receive(:production?).and_return(false)
        injector.producer(kafka_config)
      end

      it "adds producer kafka dev defaults" do
        expect(kafka_config).to include(
          "allow.auto.create.topics": "true",
          "topic.metadata.refresh.interval.ms": 5_000,
          "socket.nagle.disable": true
        )
      end
    end

    context "when defaults are already present in kafka_config" do
      let(:kafka_config) do
        {
          "allow.auto.create.topics": "false",
          "topic.metadata.refresh.interval.ms": 10_000
        }
      end

      before do
        allow(Karafka::App.env).to receive(:production?).and_return(false)
        injector.producer(kafka_config)
      end

      it "does not overwrite existing settings" do
        expect(kafka_config).to eq(
          "allow.auto.create.topics": "false",
          "topic.metadata.refresh.interval.ms": 10_000,
          "socket.nagle.disable": true
        )
      end
    end
  end
end
