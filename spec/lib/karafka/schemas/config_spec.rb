# frozen_string_literal: true

RSpec.describe Karafka::Schemas::Config do
  let(:schema) { described_class }

  let(:config) do
    {
      client_id: 'name',
      topic_mapper: Karafka::Routing::TopicMapper,
      shutdown_timeout: 10,
      params_base_class: Hash
    }
  end

  context 'when config is valid' do
    it { expect(schema.call(config)).to be_success }
  end

  context 'when we validate client_id' do
    context 'when client_id is nil' do
      before { config[:client_id] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when client_id is not a string' do
      before { config[:client_id] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate shutdown_timeout' do
    context 'when shutdown_timeout is nil' do
      before { config[:shutdown_timeout] = nil }

      it { expect(schema.call(config)).to be_success }
    end

    context 'when shutdown_timeout is not an int' do
      before { config[:shutdown_timeout] = 2.1 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when shutdown_timeout is less then 0' do
      before { config[:shutdown_timeout] = -2 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate params_base_class' do
    context 'when params_base_class are missing' do
      before { config[:params_base_class] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end
  end
end
