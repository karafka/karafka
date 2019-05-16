# frozen_string_literal: true

RSpec.describe Karafka::Connection::ApiAdapter do
  let(:consumer) { Karafka::BaseConsumer }
  let(:topic) { rand.to_s }
  let(:attributes_map_values) { Karafka::AttributesMap.api_adapter }
  let(:consumer_group) do
    Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
      cg.public_send(:topic=, topic) do
        consumer Class.new(Karafka::BaseConsumer)
        backend :inline
      end
    end
  end
  let(:custom_mapper) do
    ClassBuilder.build do
      def self.outgoing(topic)
        "remapped-#{topic}"
      end
    end
  end

  describe '#client' do
    subject(:config) { described_class.client }

    let(:expected_keys) { (attributes_map_values[:consumer] + %i[group_id]).sort }

    it 'not to have any api_adapter keys' do
      keys = config.last.keys - Karafka::AttributesMap.api_adapter.values.flatten
      expect(keys).to eq config.last.keys
    end

    it 'expect to have std kafka config keys' do
      expected = %i[
        logger client_id connect_timeout socket_timeout sasl_plain_authzid
        ssl_ca_certs_from_system sasl_over_ssl
      ]
      expect(config.last.keys.sort).to eq expected.sort
    end

    it 'expect to have as a first argument seed_brokers' do
      expect(config.first).to eq %w[kafka://localhost:9092]
    end

    context 'when values of keys are not nil' do
      let(:unsupported_keys) do
        %i[ssl_client_cert_chain ssl_client_cert_key_password sasl_oauth_token_provider]
      end
      let(:expected_keys) do
        Kafka::Client.instance_method(:initialize).parameters.map(&:last).sort
      end

      before do
        hashed_details = ::Karafka::App.config.kafka.to_h
        allow(::Karafka::App.config.kafka).to receive(:to_h).and_return(hashed_details)

        expected_keys.each do |client_key|
          # This line will skip settings that are defined somewhere else (on config root level)
          # or new not supported settings
          next unless Karafka::App.config.kafka.respond_to?(client_key)
          hashed_details[client_key] = rand.to_s
        end
      end

      it 'expect to have all the keys as kafka requires' do
        expect(config.last.keys.sort).to eq(expected_keys - %i[seed_brokers] - unsupported_keys)
      end
    end
  end

  describe '#consumer' do
    subject(:config) { described_class.consumer(consumer_group) }

    let(:expected_keys) { (attributes_map_values[:consumer] + %i[group_id]).sort }

    it 'expect not to have anything else than consumer specific options + group_id' do
      expect(config.last.keys.sort).to eq expected_keys
    end
  end

  describe '#consumption' do
    subject(:config) { described_class.consumption(consumer_group) }

    let(:expected_keys) { attributes_map_values[:consumption].sort }

    it 'expect to have consuming specific options and remap of automatically_mark_as_processed' do
      expect(config.first.keys.sort).to eq([:automatically_mark_as_processed] + expected_keys)
    end

    it 'expect to get automatic marking from consume to processed' do
      remap_value = rand
      consumer_group.automatically_mark_as_consumed = remap_value
      expect(config.last[:automatically_mark_as_processed]).to eq remap_value
    end

    context 'when consuming group has some non default options' do
      let(:consumer_group) do
        Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
          cg.send(:max_wait_time=, 0.5)

          cg.public_send(:topic=, topic) do
            consumer Class.new(Karafka::BaseConsumer)
            backend :inline
          end
        end
      end

      it 'expect to use it instead of default' do
        expect(config.last[:max_wait_time]).to eq 0.5
      end
    end
  end

  describe '#pause' do
    subject(:config) { described_class.pause(topic, partition, consumer_group) }

    let(:topic) { 'topic-name' }
    let(:partition) { 0 }

    it 'expect not to have anything else except timeout in the settings hash' do
      expect(config.last.keys.sort).to eq %i[timeout]
    end

    it 'expect to have topic name as a first argument' do
      expect(config[0]).to eq topic
    end

    it 'expect to have partition as a second argument' do
      expect(config[1]).to eq partition
    end

    context 'when we use custom mapper for topic' do
      before { allow(Karafka::App.config).to receive(:topic_mapper).and_return(custom_mapper) }

      it 'expect to use it before passing data further to kafka' do
        expect(config[0]).to eq "remapped-#{topic}"
      end
    end
  end

  describe '#subscribe' do
    subject(:config) { described_class.subscribe(consumer_group.topics.first) }

    let(:expected_keys) { attributes_map_values[:subscribe].sort }

    it 'expect not to have anything else than subscribe specific options' do
      expect(config.last.keys.sort).to eq expected_keys
    end

    it { expect(config.first).to eq consumer_group.topics.first.name }

    context 'with a custom topic mapper' do
      let(:custom_mapper) do
        ClassBuilder.build do
          def self.outgoing(topic)
            "prefix.#{topic}"
          end
        end
      end

      before { allow(Karafka::App.config).to receive(:topic_mapper).and_return(custom_mapper) }

      it { expect(config.first).to eq custom_mapper.outgoing(consumer_group.topics.first.name) }
    end
  end

  describe '#mark_message_as_processed' do
    subject(:config) { described_class.mark_message_as_processed(params) }

    let(:params) { Karafka::Params::Params.new.tap { |params| params['topic'] = 'topic-name' } }

    context 'when the default mapper is used' do
      it 'expect to return exactly the same params instance as no changes needed' do
        expect(config).to eql [params]
      end
    end

    context 'when custom mapper is being used' do
      before { allow(Karafka::App.config).to receive(:topic_mapper).and_return(custom_mapper) }

      it 'expect to return w new params instance with remapped topic' do
        expect(config).not_to eql [params]
        expect(config.first.topic).to eq "remapped-#{params.topic}"
      end
    end
  end
end
