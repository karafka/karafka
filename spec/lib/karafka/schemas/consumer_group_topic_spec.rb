# frozen_string_literal: true

RSpec.describe Karafka::Schemas::ConsumerGroupTopic do
  let(:schema) { described_class }

  let(:config) do
    {
      id: 'id',
      name: 'name',
      backend: :inline,
      controller: Class.new,
      parser: Class.new,
      max_bytes_per_partition: 1,
      start_from_beginning: true,
      batch_processing: true,
      persistent: false
    }
  end

  context 'config is valid' do
    it { expect(schema.call(config)).to be_success }
  end

  context 'id validator' do
    it 'id is nil' do
      config[:id] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'id is not a string' do
      config[:id] = 2
      expect(schema.call(config)).not_to be_success
    end

    it 'id is an invalid string' do
      config[:id] = '%^&*('
      expect(schema.call(config)).not_to be_success
    end
  end

  context 'name validator' do
    it 'name is nil' do
      config[:name] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'name is not a string' do
      config[:name] = 2
      expect(schema.call(config)).not_to be_success
    end

    it 'name is an invalid string' do
      config[:name] = '%^&*('
      expect(schema.call(config)).not_to be_success
    end
  end

  context 'backend validator' do
    it 'backend is nil' do
      config[:backend] = nil
      expect(schema.call(config)).not_to be_success
    end
  end

  context 'max_bytes_per_partition validator' do
    it 'max_bytes_per_partition is nil' do
      config[:max_bytes_per_partition] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'max_bytes_per_partition is not integer' do
      config[:max_bytes_per_partition] = 's'
      expect(schema.call(config)).not_to be_success
    end

    it 'max_bytes_per_partition is less than 0' do
      config[:max_bytes_per_partition] = -1
      expect(schema.call(config)).not_to be_success
    end
  end

  context 'start_from_beginning validator' do
    it 'start_from_beginning is nil' do
      config[:start_from_beginning] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'start_from_beginning is not a bool' do
      config[:start_from_beginning] = 2
      expect(schema.call(config)).not_to be_success
    end
  end

  context 'controller validator' do
    it 'controller is not present' do
      config[:controller] = nil
      expect(schema.call(config)).not_to be_success
    end
  end

  context 'parser validator' do
    it 'parser is not present' do
      config[:parser] = nil
      expect(schema.call(config)).not_to be_success
    end
  end

  context 'batch_processing validator' do
    it 'batch_processing is nil' do
      config[:batch_processing] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'batch_processing is not a bool' do
      config[:batch_processing] = 2
      expect(schema.call(config)).not_to be_success
    end
  end
end
