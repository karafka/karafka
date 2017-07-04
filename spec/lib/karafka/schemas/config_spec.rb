# frozen_string_literal: true

RSpec.describe Karafka::Schemas::Config do
  let(:schema) { described_class }

  let(:config) do
    {
      name: 'name',
      topic_mapper: Karafka::Routing::Mapper,
      redis: { url: 'url' },
      kafka: {
        seed_brokers: ['localhost:9092'],
        offset_commit_interval: 1,
        offset_commit_threshold: 1,
        heartbeat_interval: 1,
        session_timeout: 1,
        ssl_ca_cert: 'ca_cert',
        ssl_client_cert: 'client_cert',
        ssl_client_cert_key: 'client_cert_key',
        max_bytes_per_partition: 1_048_576,
        offset_retention_time: 1000,
        start_from_beginning: true
      }
    }
  end

  context 'config is valid' do
    it { expect(schema.call(config).success?).to be_truthy }
  end

  context 'name validator' do
    it 'name is nil' do
      config[:name] = nil
      expect(schema.call(config).success?).to be_falsey
    end

    it 'name is not a string' do
      config[:name] = 2
      expect(schema.call(config).success?).to be_falsey
    end
  end

  context 'inline_mode validator' do
    it 'inline_mode is nil' do
      config[:inline_mode] = nil
      expect(schema.call(config).success?).to be_falsey
    end

    it 'inline_mode is not a bool' do
      config[:inline_mode] = 2
      expect(schema.call(config).success?).to be_falsey
    end
  end

  context 'redis validator' do
    before do
      config[:redis] = { url: 'url' }
    end

    context 'inline_mode is true' do
      before do
        config[:inline_mode] = true
      end

      it 'redis is nil' do
        config[:redis] = nil
        expect(schema.call(config).success?).to be_truthy
      end
    end

    context 'inline_mode is false' do
      before do
        config[:inline_mode] = false
      end

      it 'redis is nil' do
        config[:redis] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      context 'redis is a hash' do
        context 'url validator' do
          it 'url is nil' do
            config[:redis][:url] = nil
            expect(schema.call(config).success?).to be_falsey
          end

          it 'url is not a string' do
            config[:redis][:url] = 2
            expect(schema.call(config).success?).to be_falsey
          end
        end
      end
    end
  end

  context 'batch_mode validator' do
    it 'batch_mode is nil' do
      config[:batch_mode] = nil
      expect(schema.call(config).success?).to be_falsey
    end

    it 'batch_mode is not a bool' do
      config[:batch_mode] = 2
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

  context 'kafka validator' do
    it 'kafka is nil' do
      config[:kafka] = nil
      expect(schema.call(config).success?).to be_falsey
    end

    it 'kafka is an empty hash' do
      config[:kafka] = {}
      expect(schema.call(config).success?).to be_falsey
    end

    it 'kafka is not a hash' do
      config[:kafka] = 'kafka'
      expect(schema.call(config).success?).to be_falsey
    end

    context 'start_from_beginning validator' do
      it 'start_from_beginning is nil' do
        config[:kafka][:start_from_beginning] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'start_from_beginning is not a bool' do
        config[:kafka][:start_from_beginning] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'seed_brokers validator' do
      it 'seed_brokers is nil' do
        config[:kafka][:seed_brokers] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'seed_brokers is an empty array' do
        config[:kafka][:seed_brokers] = []
        expect(schema.call(config).success?).to be_falsey
      end

      it 'seed_brokers is not an array' do
        config[:kafka][:seed_brokers] = 'timeout'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'offset_retention_time validator' do
      it 'offset_retention_time is not integer' do
        config[:kafka][:offset_retention_time] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'session_timeout validator' do
      it 'session_timeout is nil' do
        config[:kafka][:session_timeout] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'session_timeout is not integer' do
        config[:kafka][:session_timeout] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'offset_commit_interval validator' do
      it 'offset_commit_interval is nil' do
        config[:kafka][:offset_commit_interval] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'offset_commit_interval is not integer' do
        config[:kafka][:offset_commit_interval] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'offset_commit_threshold validator' do
      it 'offset_commit_threshold is nil' do
        config[:kafka][:offset_commit_threshold] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'offset_commit_threshold is not integer' do
        config[:kafka][:offset_commit_threshold] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'max_bytes_per_partition validator' do
      it 'max_bytes_per_partition is nil' do
        config[:kafka][:max_bytes_per_partition] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'max_bytes_per_partition is not integer' do
        config[:kafka][:max_bytes_per_partition] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'heartbeat_interval validator' do
      it 'heartbeat_interval is nil' do
        config[:kafka][:heartbeat_interval] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'heartbeat_interval is not integer' do
        config[:kafka][:heartbeat_interval] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'ssl_ca_cert validator' do
      it 'ssl_ca_cert is nil' do
        config[:kafka][:ssl_ca_cert] = nil
        expect(schema.call(config).success?).to be_truthy
      end

      it 'ssl_ca_cert is not a string' do
        config[:kafka][:ssl_ca_cert] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'ssl_client_cert validator' do
      it 'ssl_client_cert is nil' do
        config[:kafka][:ssl_client_cert] = nil
        expect(schema.call(config).success?).to be_truthy
      end

      it 'ssl_client_cert is not a string' do
        config[:kafka][:ssl_client_cert] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'ssl_client_cert_key validator' do
      it 'ssl_client_cert_key is nil' do
        config[:kafka][:ssl_client_cert_key] = nil
        expect(schema.call(config).success?).to be_truthy
      end

      it 'ssl_client_cert_key is not a string' do
        config[:kafka][:ssl_client_cert_key] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'sasl_gssapi_principal validator' do
      it 'sasl_gssapi_principal is nil' do
        config[:kafka][:sasl_gssapi_principal] = nil
        expect(schema.call(config).success?).to be_truthy
      end

      it 'sasl_gssapi_principal is not a string' do
        config[:kafka][:sasl_gssapi_principal] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'sasl_gssapi_keytab validator' do
      it 'sasl_gssapi_keytab is nil' do
        config[:kafka][:sasl_gssapi_keytab] = nil
        expect(schema.call(config).success?).to be_truthy
      end

      it 'sasl_gssapi_keytab is not a string' do
        config[:kafka][:sasl_gssapi_keytab] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end
  end
end
