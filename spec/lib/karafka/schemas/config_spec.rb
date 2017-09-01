# frozen_string_literal: true

RSpec.describe Karafka::Schemas::Config do
  let(:schema) { described_class }

  let(:config) do
    {
      client_id: 'name',
      topic_mapper: Karafka::Routing::Mapper
    }
  end

  context 'config is valid' do
    it { expect(schema.call(config).success?).to be_truthy }
  end

  context 'client_id validator' do
    it 'client_id is nil' do
      config[:client_id] = nil
      expect(schema.call(config).success?).to be_falsey
    end

    it 'client_id is not a string' do
      config[:client_id] = 2
      expect(schema.call(config).success?).to be_falsey
    end
  end

  context 'connection_pool validator' do
    it 'connection_pool is nil' do
      config[:connection_pool] = nil
      expect(schema.call(config).success?).to be_falsey
    end

    it 'connection_pool is not a hash' do
      config[:connection_pool] = 2
      expect(schema.call(config).success?).to be_falsey
    end

    context 'connection_pool is a hash' do
      before do
        config[:connection_pool] = { size: 1, timeout: 2 }
      end

      context 'size validator' do
        it 'size is nil' do
          config[:connection_pool][:size] = nil
          expect(schema.call(config).success?).to be_falsey
        end
      end

      context 'timeout validator' do
        it 'timeout is nil' do
          config[:connection_pool][:timeout] = nil
          expect(schema.call(config).success?).to be_falsey
        end

        it 'timeout is not a hash' do
          config[:connection_pool][:timeout] = 's'
          expect(schema.call(config).success?).to be_falsey
        end
      end
    end
  end
end
