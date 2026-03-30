# frozen_string_literal: true

RSpec.describe_current do
  subject(:replacer) { described_class.new }

  let(:kafka) { Karafka::App.config.kafka.dup }
  let(:logger) { Karafka::App.config.logger }

  let(:old_producer) do
    WaterDrop::Producer.new do |p_config|
      p_config.kafka = Karafka::Setup::AttributesMap.producer(kafka.dup)
      p_config.logger = logger
    end
  end

  after do
    old_producer.close
  rescue
    nil
  end

  describe "#call" do
    let(:new_producer) { replacer.call(old_producer, kafka, logger) }

    after do
      new_producer.close
    rescue
      nil
    end

    it "expect to return a WaterDrop::Producer" do
      expect(new_producer).to be_a(WaterDrop::Producer)
    end

    it "expect to assign a new unique id" do
      expect(new_producer.id).not_to eq(old_producer.id)
    end

    it "expect to use the provided logger" do
      expect(new_producer.config.logger).to eq(logger)
    end

    context "when old producer has custom max_payload_size" do
      let(:old_producer) do
        WaterDrop::Producer.new do |p_config|
          p_config.kafka = Karafka::Setup::AttributesMap.producer(kafka.dup)
          p_config.logger = logger
          p_config.max_payload_size = 999
        end
      end

      it "expect to inherit max_payload_size" do
        expect(new_producer.config.max_payload_size).to eq(999)
      end
    end

    context "when old producer has custom max_wait_timeout" do
      let(:old_producer) do
        WaterDrop::Producer.new do |p_config|
          p_config.kafka = Karafka::Setup::AttributesMap.producer(kafka.dup)
          p_config.logger = logger
          p_config.max_wait_timeout = 30_000
        end
      end

      it "expect to inherit max_wait_timeout" do
        expect(new_producer.config.max_wait_timeout).to eq(30_000)
      end
    end

    context "when old producer has idempotent kafka settings" do
      let(:old_producer) do
        WaterDrop::Producer.new do |p_config|
          p_config.kafka = Karafka::Setup::AttributesMap.producer(kafka.dup)
          p_config.kafka[:"enable.idempotence"] = true
          p_config.logger = logger
          p_config.reload_on_idempotent_fatal_error = true
          p_config.wait_backoff_on_idempotent_fatal_error = 500
          p_config.max_attempts_on_idempotent_fatal_error = 5
        end
      end

      it "expect to preserve enable.idempotence in kafka config" do
        expect(new_producer.config.kafka[:"enable.idempotence"]).to be(true)
      end

      it "expect new producer to report as idempotent" do
        expect(new_producer.idempotent?).to be(true)
      end

      it "expect to inherit reload_on_idempotent_fatal_error" do
        expect(new_producer.config.reload_on_idempotent_fatal_error).to be(true)
      end

      it "expect to inherit wait_backoff_on_idempotent_fatal_error" do
        expect(new_producer.config.wait_backoff_on_idempotent_fatal_error).to eq(500)
      end

      it "expect to inherit max_attempts_on_idempotent_fatal_error" do
        expect(new_producer.config.max_attempts_on_idempotent_fatal_error).to eq(5)
      end
    end

    context "when old producer has producer-specific kafka settings not in app config" do
      let(:old_producer) do
        WaterDrop::Producer.new do |p_config|
          p_config.kafka = Karafka::Setup::AttributesMap.producer(kafka.dup)
          p_config.kafka[:"enable.idempotence"] = true
          p_config.kafka[:"compression.type"] = "snappy"
          p_config.logger = logger
        end
      end

      it "expect to preserve all producer-specific kafka settings" do
        expect(new_producer.config.kafka[:"enable.idempotence"]).to be(true)
        expect(new_producer.config.kafka[:"compression.type"]).to eq("snappy")
      end

      it "expect to keep app-level kafka settings" do
        expect(new_producer.config.kafka[:"bootstrap.servers"]).not_to be_nil
      end
    end

    context "when app kafka config and old producer kafka config share a key" do
      it "expect app-level value to take precedence" do
        bootstrap = new_producer.config.kafka[:"bootstrap.servers"]
        expect(bootstrap).to eq(kafka[:"bootstrap.servers"])
      end
    end

    context "when old producer has custom oauth settings" do
      let(:token_provider) do
        Class.new do
          def on_oauthbearer_token_refresh(_)
            "token"
          end
        end.new
      end

      let(:old_producer) do
        WaterDrop::Producer.new do |p_config|
          p_config.kafka = Karafka::Setup::AttributesMap.producer(kafka.dup)
          p_config.logger = logger
          p_config.oauth.token_provider_listener = token_provider
        end
      end

      it "expect to inherit oauth token_provider_listener" do
        expect(new_producer.config.oauth.token_provider_listener).to eq(token_provider)
      end
    end

    context "when old producer has custom polling settings" do
      let(:old_producer) do
        WaterDrop::Producer.new do |p_config|
          p_config.kafka = Karafka::Setup::AttributesMap.producer(kafka.dup)
          p_config.logger = logger
          p_config.polling.mode = :fd
          p_config.polling.fd.max_time = 200
          p_config.polling.fd.periodic_poll_interval = 2_000
        end
      end

      it "expect to inherit polling mode" do
        expect(new_producer.config.polling.mode).to eq(:fd)
      end

      it "expect to inherit polling fd max_time" do
        expect(new_producer.config.polling.fd.max_time).to eq(200)
      end

      it "expect to inherit polling fd periodic_poll_interval" do
        expect(new_producer.config.polling.fd.periodic_poll_interval).to eq(2_000)
      end
    end
  end
end
