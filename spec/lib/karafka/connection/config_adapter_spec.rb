# frozen_string_literal: true

RSpec.describe Karafka::Connection::ConfigAdapter do
  let(:controller) { Karafka::BaseController }
  let(:topic) { rand.to_s }
  let(:attributes_map_values) { Karafka::AttributesMap.config_adapter }
  let(:consumer_group) do
    Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
      cg.public_send(:topic=, topic) do
        controller Class.new
        inline_mode true
      end
    end
  end

  describe '#client' do
    pending
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

    let(:expected_keys) { (attributes_map_values[:consuming]).sort }

    it 'expect not to have anything else than consuming specific options' do
      expect(config.keys.sort).to eq expected_keys
    end
  end

  describe '#subscription' do
    subject(:config) { described_class.subscription(consumer_group.topics.first) }

    let(:expected_keys) { (attributes_map_values[:subscription]).sort }

    it 'expect not to have anything else than subscription specific options' do
      expect(config.last.keys.sort).to eq expected_keys
    end

    it { expect(config.first).to eq consumer_group.topics.first.name }
  end
end
