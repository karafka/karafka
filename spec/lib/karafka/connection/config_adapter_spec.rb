# frozen_string_literal: true

RSpec.describe Karafka::Connection::ConfigAdapter do
  let(:controller) { Karafka::BaseController }
  let(:topic) { rand.to_s }
  let(:attributes_map_values) { Karafka::AttributesMap.config_adapter }
  let(:consumer_group) do
    Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
      cg.public_send(:topic=, topic) do
        controller Class.new
        inline_processing true
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

    it 'expect not to have anything else than consuming specific options' do
      expect(config.keys.sort).to eq expected_keys
    end
  end

  describe '#subscription' do
    subject(:config) { described_class.subscription(consumer_group.topics.first) }

    let(:expected_keys) { attributes_map_values[:subscription].sort }

    it 'expect not to have anything else than subscription specific options' do
      expect(config.last.keys.sort).to eq expected_keys
    end

    it { expect(config.first).to eq consumer_group.topics.first.name }
  end
end
