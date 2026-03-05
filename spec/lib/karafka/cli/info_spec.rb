# frozen_string_literal: true

RSpec.describe_current do
  subject(:info_cli) { described_class.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe "#call" do
    before do
      allow(Karafka.logger).to receive(:info)
    end

    context "when running info on lgpl" do
      let(:info) do
        [
          "Karafka version: #{Karafka::VERSION}",
          "Ruby version: #{RUBY_DESCRIPTION}",
          "Rdkafka version: #{Rdkafka::VERSION}",
          "Consumer groups count: #{Karafka::App.consumer_groups.size}",
          "Subscription groups count: #{Karafka::App.subscription_groups.values.flatten.size}",
          "Workers count: #{Karafka::App.config.concurrency}",
          "Instance client id: #{Karafka::App.config.client_id}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}",
          "License: LGPL-3.0"
        ].join("\n")
      end

      before do
        Karafka::App.config.license.token = false
      end

      it "expect to print details of this Karafka app instance" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(described_class::BANNER)
        expect(Karafka.logger).to have_received(:info).with(info)
      end
    end

    context "when running info on pro" do
      let(:info) do
        [
          "Karafka version: #{Karafka::VERSION} + Pro",
          "Ruby version: #{RUBY_DESCRIPTION}",
          "Rdkafka version: #{Rdkafka::VERSION}",
          "Consumer groups count: #{Karafka::App.consumer_groups.size}",
          "Subscription groups count: #{Karafka::App.subscription_groups.values.flatten.size}",
          "Workers count: #{Karafka::App.config.concurrency}",
          "Instance client id: #{Karafka::App.config.client_id}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}",
          "License: Commercial",
          "License entity: #{Karafka::App.config.license.entity}"
        ].join("\n")
      end

      before do
        Karafka::App.config.license.token = true
        Karafka::App.config.license.entity = rand.to_s
      end

      after do
        Karafka::App.config.license.token = false
        Karafka::App.config.license.entity = ""
      end

      it "expect to print details of this Karafka app instance" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(described_class::BANNER)
        expect(Karafka.logger).to have_received(:info).with(info)
      end
    end

    context "when running without --extended" do
      before do
        Karafka::App.config.license.token = false
      end

      it "expect not to print routing info" do
        info_cli.call
        expect(Karafka.logger).not_to have_received(:info).with(/Routing/)
      end

      it "expect not to print config section" do
        info_cli.call
        expect(Karafka.logger).not_to have_received(:info).with(/========== Config/)
      end

      it "expect not to print kafka config section" do
        info_cli.call
        expect(Karafka.logger).not_to have_received(:info).with(/Kafka Config/)
      end
    end

    context "when running with --extended and a single consumer group" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          consumer_group :test_group do
            topic :test_topic do
              consumer Class.new(Karafka::BaseConsumer)
            end
          end
        end
      end

      it "expect to print routing section with consumer group" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Routing/).at_least(:once)
        expect(Karafka.logger).to have_received(:info).with(/Consumer group: test_group/)
      end

      it "expect to print topic details" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Topic: test_topic/)
      end

      it "expect to print topic attributes" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/max_messages:/).at_least(:once)
        expect(Karafka.logger).to have_received(:info).with(/max_wait_time:/).at_least(:once)
        expect(Karafka.logger).to have_received(:info).with(/initial_offset:/).at_least(:once)
      end

      it "expect to print subscription group info" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Subscription group:/)
        expect(Karafka.logger).to have_received(:info).with(/kafka\[group\.id\]:/)
      end

      it "expect to print config section" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/========== Config =/).at_least(:once)
        expect(Karafka.logger).to have_received(:info).with(/client_id:/).at_least(:once)
        expect(Karafka.logger).to have_received(:info).with(/concurrency:/).at_least(:once)
        expect(Karafka.logger).to have_received(:info).with(/shutdown_timeout:/)
      end

      it "expect to print kafka config section" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Kafka Config =/)
      end
    end

    context "when running with --extended and multiple consumer groups" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          consumer_group :group_one do
            topic :topic_a do
              consumer Class.new(Karafka::BaseConsumer)
            end
          end

          consumer_group :group_two do
            topic :topic_b do
              consumer Class.new(Karafka::BaseConsumer)
            end
          end
        end
      end

      it "expect to print both consumer groups" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Consumer group: group_one/)
        expect(Karafka.logger).to have_received(:info).with(/Consumer group: group_two/)
      end

      it "expect to print both topics" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Topic: topic_a/)
        expect(Karafka.logger).to have_received(:info).with(/Topic: topic_b/)
      end
    end

    context "when running with --extended and topic has explicit kafka overrides" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          topic :overridden_topic do
            consumer Class.new(Karafka::BaseConsumer)
            kafka(inherit: true, "auto.offset.reset": "latest")
          end
        end
      end

      it "expect to print kafka overrides" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/kafka overrides:/)
      end
    end

    context "when running with --extended and topic has no explicit kafka overrides" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          topic :plain_topic do
            consumer Class.new(Karafka::BaseConsumer)
          end
        end
      end

      it "expect not to print kafka overrides" do
        info_cli.call
        expect(Karafka.logger).not_to have_received(:info).with(/kafka overrides:/)
      end
    end

    context "when running with --extended and topic has dead_letter_queue" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          topic :dlq_topic do
            consumer Class.new(Karafka::BaseConsumer)
            dead_letter_queue(topic: "dlq_target", max_retries: 3)
          end
        end
      end

      it "expect to print dead_letter_queue feature" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Features:/)
        expect(Karafka.logger).to have_received(:info).with(/dead_letter_queue:/)
      end
    end

    context "when running with --extended and consumer group active status" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          consumer_group :active_group do
            topic :some_topic do
              consumer Class.new(Karafka::BaseConsumer)
            end
          end
        end
      end

      it "expect to print consumer group with active status" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(
          /Consumer group: active_group \(active\)/
        )
      end
    end

    context "when running with --extended and subscription group position" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          consumer_group :pos_group do
            topic :pos_topic do
              consumer Class.new(Karafka::BaseConsumer)
            end
          end
        end
      end

      it "expect to print subscription group with position" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/\[position: \d+\]/)
      end
    end

    context "when running with --extended and topic with consumer_persistence" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          topic :persistence_topic do
            consumer Class.new(Karafka::BaseConsumer)
          end
        end
      end

      it "expect to print consumer_persistence in topic details" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(
          /consumer_persistence:/
        ).at_least(:once)
      end

      it "expect to print pause settings in topic details" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/pause_timeout:/).at_least(:once)
        expect(Karafka.logger).to have_received(:info).with(/pause_max_timeout:/).at_least(:once)
        expect(Karafka.logger).to have_received(:info).with(
          /pause_with_exponential_backoff:/
        ).at_least(:once)
      end
    end

    context "when running with --extended and config settings" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)

        Karafka::App.consumer_groups.draw do
          topic :any_topic do
            consumer Class.new(Karafka::BaseConsumer)
          end
        end
      end

      it "expect to print strict config values" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/strict_topics_namespacing:/)
        expect(Karafka.logger).to have_received(:info).with(/strict_declarative_topics:/)
      end

      it "expect to print group_id" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/group_id:/)
      end
    end

    context "when running with --extended and empty routing" do
      before do
        Karafka::App.config.license.token = false
        allow(info_cli).to receive(:options).and_return(extended: true)
      end

      it "expect to print routing section header even with no groups" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Routing/)
      end

      it "expect to still print config section" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/========== Config =/).at_least(:once)
      end

      it "expect to still print kafka config section" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/Kafka Config =/)
      end
    end
  end

  describe "#names" do
    it { expect(info_cli.class.names).to eq %w[info] }
  end
end
