# frozen_string_literal: true

RSpec.describe Karafka::Schemas::ConsumerGroupTopic do
  let(:schema) { described_class }

  let(:config) do
    {
      id: 'id',
      name: 'name',
      backend: :inline,
      consumer: Class.new,
      deserializer: Class.new,
      max_bytes_per_partition: 1,
      start_from_beginning: true,
      batch_consuming: true,
      persistent: false
    }
  end

  context 'when config is valid' do
    it { expect(schema.call(config)).to be_success }
  end

  context 'when we validate id' do
    context 'when it is nil' do
      before { config[:id] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when it is not a string' do
      before { config[:id] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when it is an invalid string' do
      before { config[:id] = '%^&*(' }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate name' do
    context 'when it is nil' do
      before { config[:name] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when it is not a string' do
      before { config[:name] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when it is an invalid string' do
      before { config[:name] = '%^&*(' }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate backend' do
    context 'when it is nil' do
      before { config[:backend] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate max_bytes_per_partition' do
    context 'when it is nil' do
      before { config[:max_bytes_per_partition] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when it is not integer' do
      before { config[:max_bytes_per_partition] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when it is less than 0' do
      before { config[:max_bytes_per_partition] = -1 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate start_from_beginning' do
    context 'when it is nil' do
      before { config[:start_from_beginning] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when it is not a bool' do
      before { config[:start_from_beginning] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate consumer' do
    context 'when it is not present' do
      before { config[:consumer] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate deserializer' do
    context 'when it is not present' do
      before { config[:deserializer] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate batch_consuming' do
    context 'when it is nil' do
      before { config[:batch_consuming] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when it is not a bool' do
      before { config[:batch_consuming] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end
end
