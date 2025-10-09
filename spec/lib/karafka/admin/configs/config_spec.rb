# frozen_string_literal: true

RSpec.describe_current do
  let(:name) { 'test_config' }
  let(:value) { 'test_value' }
  let(:default) { -1 }
  let(:read_only) { -1 }
  let(:sensitive) { -1 }
  let(:synonym) { -1 }
  let(:synonyms) { [] }
  let(:config) do
    described_class.new(
      name: name,
      value: value,
      default: default,
      read_only: read_only,
      sensitive: sensitive,
      synonym: synonym,
      synonyms: synonyms
    )
  end

  describe '#initialize' do
    subject(:initialized_config) { config }

    context 'with minimum input' do
      let(:default) { 0 }
      let(:read_only) { 0 }
      let(:sensitive) { 0 }
      let(:synonym) { 0 }

      it 'initializes correctly with name and value' do
        expect(initialized_config.name).to eq(name)
        expect(initialized_config.value).to eq(value)
      end
    end

    context 'when additional attributes are provided' do
      let(:default) { 1 }
      let(:read_only) { 1 }
      let(:sensitive) { 1 }
      let(:synonym) { 1 }

      it 'initializes correctly with all attributes' do
        expect(initialized_config.default?).to be true
        expect(initialized_config.read_only?).to be true
        expect(initialized_config.sensitive?).to be true
        expect(initialized_config.synonym?).to be true
      end
    end
  end

  describe '#default?' do
    subject(:is_default) { config.default? }

    context 'when config is default' do
      let(:default) { 1 }

      it { is_expected.to be true }
    end

    context 'when config is not default' do
      let(:default) { 0 }

      it { is_expected.to be false }
    end
  end

  describe '#read_only?' do
    subject(:is_read_only) { config.read_only? }

    context 'when config is read only' do
      let(:read_only) { 1 }

      it { is_expected.to be true }
    end

    context 'when config is not read only' do
      let(:read_only) { 0 }

      it { is_expected.to be false }
    end
  end

  describe '#sensitive?' do
    subject(:is_sensitive) { config.sensitive? }

    context 'when config is sensitive' do
      let(:sensitive) { 1 }

      it { is_expected.to be true }
    end

    context 'when config is not sensitive' do
      let(:sensitive) { 0 }

      it { is_expected.to be false }
    end
  end

  describe '#synonym?' do
    subject(:is_synonym) { config.synonym? }

    context 'when config is a synonym' do
      let(:synonym) { 1 }

      it { is_expected.to be true }
    end

    context 'when config is not a synonym' do
      let(:synonym) { 0 }

      it { is_expected.to be false }
    end
  end

  describe '.from_rd_kafka' do
    let(:synonym_config) do
      instance_double(
        Rdkafka::Admin::ConfigBindingResult,
        name: 'test_synonym',
        value: 'synonym_value',
        read_only: 1,
        default: 1,
        sensitive: 1,
        synonym: 1,
        synonyms: []
      )
    end

    let(:rd_kafka_config) do
      instance_double(
        Rdkafka::Admin::ConfigBindingResult,
        name: name,
        value: value,
        read_only: 1,
        default: 1,
        sensitive: 1,
        synonym: 1,
        synonyms: [synonym_config]
      )
    end

    subject(:config_from_rd_kafka) { described_class.from_rd_kafka(rd_kafka_config) }

    it 'creates a config with synonyms correctly' do
      expect(config_from_rd_kafka.name).to eq(name)
      expect(config_from_rd_kafka.value).to eq(value)
      expect(config_from_rd_kafka.synonyms.first.name).to eq('test_synonym')
      expect(config_from_rd_kafka.synonyms.first.value).to eq('synonym_value')
    end
  end

  describe '#to_native_hash' do
    subject(:native_hash) { config.to_native_hash }

    it 'returns a hash with name and value' do
      expect(native_hash[:name]).to eq(name)
      expect(native_hash[:value]).to eq(value)
    end
  end
end
