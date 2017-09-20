# frozen_string_literal: true

RSpec.describe Karafka::Schemas::Config do
  let(:schema) { described_class }

  let(:config) do
    {
      client_id: 'name',
      topic_mapper: Karafka::Routing::Mapper,
      celluloid: {
        shutdown_timeout: 30
      }
    }
  end

  context 'config is valid' do
    it { expect(schema.call(config)).to be_success }
  end

  context 'client_id validator' do
    it 'client_id is nil' do
      config[:client_id] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'client_id is not a string' do
      config[:client_id] = 2
      expect(schema.call(config)).not_to be_success
    end
  end

  context 'connection_pool validator' do
    it 'connection_pool is nil' do
      config[:connection_pool] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'connection_pool is not a hash' do
      config[:connection_pool] = 2
      expect(schema.call(config)).not_to be_success
    end

    context 'connection_pool is a hash' do
      before do
        config[:connection_pool] = { size: 1, timeout: 2 }
      end

      context 'size validator' do
        it 'size is nil' do
          config[:connection_pool][:size] = nil
          expect(schema.call(config)).not_to be_success
        end
      end

      context 'timeout validator' do
        it 'timeout is nil' do
          config[:connection_pool][:timeout] = nil
          expect(schema.call(config)).not_to be_success
        end

        it 'timeout is not a hash' do
          config[:connection_pool][:timeout] = 's'
          expect(schema.call(config)).not_to be_success
        end
      end
    end
  end

  context 'celluloid validator' do
    it 'celluloid is nil' do
      config[:celluloid] = nil
      expect(schema.call(config)).not_to be_success
    end

    it 'celluloid is not a hash' do
      config[:celluloid] = 2
      expect(schema.call(config)).not_to be_success
    end

    context 'celluloid is a hash' do
      before do
        config[:celluloid] = { shutdown_timeout: 2 }
      end

      context 'shutdown_timeout validator' do
        it 'shutdown_timeout is nil' do
          config[:celluloid][:shutdown_timeout] = nil
          expect(schema.call(config)).not_to be_success
        end

        it 'shutdown_timeout is less then 0' do
          config[:celluloid][:shutdown_timeout] = (rand(100) * -1) - 1
          expect(schema.call(config)).not_to be_success
        end
      end
    end
  end
end
