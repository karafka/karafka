# frozen_string_literal: true

RSpec.describe Karafka::Connection::ConfigAdapter do
  let(:consumer) { Karafka::BaseConsumer }
  let(:topic) { rand.to_s }
  let(:attributes_map_values) { Karafka::AttributesMap.config_adapter }
  let(:consumer_group) do
    Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
      cg.public_send(:topic=, topic) do
        consumer Class.new(Karafka::BaseConsumer)
        backend :inline
      end
    end
  end

  describe '#client' do
    subject(:config) { described_class.client(consumer_group) }

    let(:expected_keys) { (attributes_map_values[:consumer] + %i[group_id]).sort }

    it 'not to have any config_adapter keys' do
      expect(config.keys - Karafka::AttributesMap.config_adapter.values.flatten).to eq config.keys
    end

    it 'expect to have std kafka config keys' do
      expected = %i[
        logger client_id seed_brokers connect_timeout socket_timeout sasl_plain_authzid
      ]
      expect(config.keys.sort).to eq expected.sort
    end

    context 'when values of keys are not nil' do
      let(:expected_keys) do
        Kafka::Client.instance_method(:initialize).parameters.map(&:last).sort
      end

      before do
        hashed_details = ::Karafka::App.config.kafka.to_h
        expect(::Karafka::App.config.kafka).to receive(:to_h).and_return(hashed_details)

        expected_keys.each do |client_key|
          # This line will skip settings that are defined somewhere else (on config root level)
          # or new not supported settings
          next unless Karafka::App.config.kafka.respond_to?(client_key)
          hashed_details[client_key] = rand.to_s
        end
      end

      it 'expect to have all the keys as kafka requires' do
        expect(config.keys.sort).to eq expected_keys
      end
    end
  end

  describe '#consumer' do
    subject(:config) { described_class.consumer(consumer_group) }

    let(:expected_keys) { (attributes_map_values[:consumer] + %i[group_id]).sort }

    it 'expect not to have anything else than consumer specific options + group_id' do
      expect(config.keys.sort).to eq expected_keys
    end
  end

  describe '#consuming' do
    subject(:config) { described_class.consuming(consumer_group) }

    let(:expected_keys) { attributes_map_values[:consuming].sort }

    it 'expect to have consuming specific options and remap of automatically_mark_as_processed' do
      expect(config.keys.sort).to eq([:automatically_mark_as_processed] + expected_keys)
    end

    it 'expect to get automatic marking from consume to processed' do
      remap_value = rand
      consumer_group.automatically_mark_as_consumed = remap_value
      expect(config[:automatically_mark_as_processed]).to eq remap_value
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
        expect(config[:max_wait_time]).to eq 0.5
      end
    end
  end

  describe '#pausing' do
    subject(:config) { described_class.pausing(consumer_group) }

    it 'expect not to have anything else except timeout' do
      expect(config.keys.sort).to eq %i[timeout]
    end
  end

  describe '#subscription' do
    subject(:config) { described_class.subscription(consumer_group.topics.first) }

    let(:expected_keys) { attributes_map_values[:subscription].sort }

    it 'expect not to have anything else than subscription specific options' do
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

      before { expect(Karafka::App.config).to receive(:topic_mapper).and_return(custom_mapper) }

      it { expect(config.first).to eq custom_mapper.outgoing(consumer_group.topics.first.name) }
    end
  end
end
