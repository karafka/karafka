# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      id: "id",
      name: "name",
      active: true,
      consumer: Class.new,
      deserializing: {},
      kafka: { "bootstrap.servers": "localhost:9092" },
      max_messages: 10,
      max_wait_time: 10_000,
      initial_offset: "earliest",
      subscription_group_details: {
        name: SecureRandom.hex(6)
      }
    }
  end

  context "when we check for the errors yml file reference" do
    it "expect to have all of them defined" do
      stringified = described_class.config.error_messages.to_s

      described_class.rules.each do |rule|
        expect(stringified).to include(rule.path.last.to_s)
      end
    end
  end

  context "when config is valid" do
    it { expect(check).to be_success }
  end

  context "when we validate id" do
    context "when it is nil" do
      before { config[:id] = nil }

      it { expect(check).not_to be_success }
    end

    context "when it is not a string" do
      before { config[:id] = 2 }

      it { expect(check).not_to be_success }
    end

    context "when it is an invalid string" do
      before { config[:id] = "%^&*(" }

      it { expect(check).not_to be_success }
    end
  end

  context "when we validate name" do
    context "when it is nil" do
      before { config[:name] = nil }

      it { expect(check).not_to be_success }
    end

    context "when it is not a string" do
      before { config[:name] = 2 }

      it { expect(check).not_to be_success }
    end

    context "when it is an invalid string" do
      before { config[:name] = "%^&*(" }

      it { expect(check).not_to be_success }
    end

    context "when considering namespaces" do
      context "with consistent namespacing style" do
        context "with dot style" do
          before { config[:name] = "yc.auth.cmd.shopper-registrations.1" }

          it { expect(check).to be_success }
        end

        context "with underscore style" do
          before { config[:name] = "yc_auth_cmd_shopper-registrations_1" }

          it { expect(check).to be_success }
        end
      end

      context "with inconsistent namespacing style" do
        before { config[:name] = "yc.auth.cmd.shopper-registrations_1" }

        it { expect(check).not_to be_success }
      end

      context "when strict_topics_namespacing is set to false" do
        before do
          config[:name] = "yc.auth.cmd.shopper-registrations_1"
          Karafka::App.config.strict_topics_namespacing = false
        end

        after { Karafka::App.config.strict_topics_namespacing = true }

        it { expect(check).to be_success }
      end
    end
  end

  context "when we validate subscription_group_details" do
    context "when name is nil" do
      before { config[:subscription_group_details][:name] = nil }

      it { expect(check).not_to be_success }
    end

    context "when name is not a string" do
      before { config[:subscription_group_details][:name] = 2 }

      it { expect(check).not_to be_success }
    end

    context "when it is an empty string" do
      before { config[:subscription_group_details][:name] = "" }

      it { expect(check).not_to be_success }
    end
  end

  context "when validating max_messages" do
    context "when not numeric" do
      before { config[:max_messages] = "100" }

      it { expect(check).not_to be_success }
    end

    context "when zero" do
      before { config[:max_messages] = 0 }

      it { expect(check).not_to be_success }
    end

    context "when missing" do
      before { config.delete(:max_messages) }

      it { expect(check).not_to be_success }
    end
  end

  context "when validating max_wait_time" do
    context "when not numeric" do
      before { config[:max_wait_time] = "100" }

      it { expect(check).not_to be_success }
    end

    context "when zero" do
      before { config[:max_wait_time] = 0 }

      it { expect(check).not_to be_success }
    end

    context "when missing" do
      before { config.delete(:max_wait_time) }

      it { expect(check).not_to be_success }
    end
  end

  context "when we validate consumer" do
    context "when it is not present" do
      before { config[:consumer] = nil }

      it { expect(check).not_to be_success }
    end

    context "when topic is not active" do
      before do
        config[:consumer] = nil
        config[:active] = false
      end

      it "expect not to require consumer" do
        expect(check).to be_success
      end
    end
  end

  context "when we validate active" do
    context "when it is nil" do
      before { config[:active] = nil }

      it { expect(check).not_to be_success }
    end

    context "when it is not a boolean" do
      before { config[:active] = 2 }

      it { expect(check).not_to be_success }
    end
  end

  context "when we validate deserializing" do
    context "when it is not present" do
      before { config[:deserializing] = nil }

      it { expect(check).not_to be_success }
    end
  end

  context "when kafka contains errors from rdkafka" do
    before { config[:kafka] = { "message.max.bytes" => 0 } }

    it { expect(check).not_to be_success }
  end

  context "when kafka has some stuff but not bootstrap servers" do
    before { config[:kafka] = { "message.max.bytes" => 1_000 } }

    it { expect(check).not_to be_success }
  end

  context "when kafka is missing totally" do
    before { config.delete(:kafka) }

    it { expect(check).not_to be_success }
  end

  context "when kafka is not a hash" do
    before { config[:kafka] = rand }

    it { expect(check).not_to be_success }
  end

  context "when we validate initial_offset" do
    context "when it is not present" do
      before { config[:initial_offset] = nil }

      it { expect(check).not_to be_success }
    end

    context "when earliest" do
      before { config[:initial_offset] = "earliest" }

      it { expect(check).to be_success }
    end

    context "when latest" do
      before { config[:initial_offset] = "latest" }

      it { expect(check).to be_success }
    end

    context "when not supported" do
      before { config[:initial_offset] = rand.to_s }

      it { expect(check).not_to be_success }
    end
  end
end
