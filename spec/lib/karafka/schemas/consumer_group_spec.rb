# frozen_string_literal: true

RSpec.describe Karafka::Schemas::ConsumerGroup do
  let(:schema) { described_class }

  let(:topics) do
    [
      {
        id: 'id',
        name: 'name',
        inline_processing: true,
        controller: Class.new,
        parser: Class.new,
        interchanger: Class.new,
        max_bytes_per_partition: 1,
        start_from_beginning: true,
        batch_processing: true
      }
    ]
  end
  let(:config) do
    {
      id: 'id',
      topic_mapper: Karafka::Routing::Mapper,
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
      start_from_beginning: true,
      connect_timeout: 10,
      socket_timeout: 10,
      max_wait_time: 10,
      batch_consuming: true,
      topics: topics
    }
  end

  context 'config is valid' do
    it { expect(schema.call(config).success?).to be_truthy }
  end

  context 'consumer group level' do
    context 'id validator' do
      it 'id is nil' do
        config[:id] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'id is not a string' do
        config[:id] = 2
        expect(schema.call(config).success?).to be_falsey
      end

      it 'id is an invalid string' do
        config[:id] = '%^&*('
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'seed_brokers validator' do
      it 'seed_brokers is nil' do
        config[:seed_brokers] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'seed_brokers is an empty array' do
        config[:seed_brokers] = []
        expect(schema.call(config).success?).to be_falsey
      end

      it 'seed_brokers is not an array' do
        config[:seed_brokers] = 'timeout'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'session_timeout validator' do
      it 'session_timeout is nil' do
        config[:session_timeout] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'session_timeout is not integer' do
        config[:session_timeout] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'offset_commit_interval validator' do
      it 'offset_commit_interval is nil' do
        config[:offset_commit_interval] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'offset_commit_interval is not integer' do
        config[:offset_commit_interval] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'offset_commit_threshold validator' do
      it 'offset_commit_threshold is nil' do
        config[:offset_commit_threshold] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'offset_commit_threshold is not integer' do
        config[:offset_commit_threshold] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'offset_retention_time validator' do
      it 'offset_retention_time is not integer' do
        config[:offset_retention_time] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'heartbeat_interval validator' do
      it 'heartbeat_interval is nil' do
        config[:heartbeat_interval] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'heartbeat_interval is not integer' do
        config[:heartbeat_interval] = 's'
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'topic_mapper validator' do
      it 'topic_mapper is not present' do
        config[:topic_mapper] = nil
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'connect_timeout validator' do
      it 'connect_timeout is nil' do
        config[:connect_timeout] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'connect_timeout is not integer' do
        config[:connect_timeout] = 's'
        expect(schema.call(config).success?).to be_falsey
      end

      it 'connect_timeout is 0' do
        config[:connect_timeout] = 0
        expect(schema.call(config).success?).to be_falsey
      end

      it 'connect_timeout is less than 0' do
        config[:connect_timeout] = -1
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'socket_timeout validator' do
      it 'socket_timeout is nil' do
        config[:socket_timeout] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'socket_timeout is not integer' do
        config[:socket_timeout] = 's'
        expect(schema.call(config).success?).to be_falsey
      end

      it 'socket_timeout is 0' do
        config[:socket_timeout] = 0
        expect(schema.call(config).success?).to be_falsey
      end

      it 'socket_timeout is less than 0' do
        config[:socket_timeout] = -1
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'max_wait_time validator' do
      it 'max_wait_time is nil' do
        config[:max_wait_time] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'max_wait_time is not integer' do
        config[:max_wait_time] = 's'
        expect(schema.call(config).success?).to be_falsey
      end

      it 'max_wait_time is less than 0' do
        config[:max_wait_time] = -1
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'batch_consuming validator' do
      it 'batch_consuming is nil' do
        config[:batch_consuming] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'batch_consuming is not a bool' do
        config[:batch_consuming] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'max_wait_time bigger than socket_timeout' do
      it 'expect to disallow' do
        config[:max_wait_time] = 2
        config[:socket_timeout] = 1
        expect(schema.call(config).success?).to be_falsey
      end
    end

    %i[
      ssl_ca_cert
      ssl_ca_cert_file_path
      ssl_client_cert
      ssl_client_cert_key
      sasl_plain_authzid
      sasl_plain_username
      sasl_plain_password
      sasl_gssapi_principal
      sasl_gssapi_keytab
    ].each do |encryption_attribute|
      context "#{encryption_attribute} validator" do
        it "#{encryption_attribute} is nil" do
          config[encryption_attribute] = nil
          expect(schema.call(config).success?).to be_truthy
        end

        it "#{encryption_attribute} is not a string" do
          config[encryption_attribute] = 2
          expect(schema.call(config).success?).to be_falsey
        end
      end
    end
  end

  context 'topics level' do
    it 'topics is an empty array' do
      config[:topics] = []
      expect(schema.call(config).success?).to be_falsey
    end

    it 'topics is not an array' do
      config[:topics] = nil
      expect(schema.call(config).success?).to be_falsey
    end

    context 'id validator' do
      it 'id is nil' do
        config[:topics][0][:id] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'id is not a string' do
        config[:topics][0][:id] = 2
        expect(schema.call(config).success?).to be_falsey
      end

      it 'id is an invalid string' do
        config[:topics][0][:id] = '%^&*('
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'name validator' do
      it 'name is nil' do
        config[:topics][0][:name] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'name is not a string' do
        config[:topics][0][:name] = 2
        expect(schema.call(config).success?).to be_falsey
      end

      it 'name is an invalid string' do
        config[:topics][0][:name] = '%^&*('
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'inline_processing validator' do
      it 'inline_processing is nil' do
        config[:topics][0][:inline_processing] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'inline_processing is not a bool' do
        config[:topics][0][:inline_processing] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'max_bytes_per_partition validator' do
      it 'max_bytes_per_partition is nil' do
        config[:topics][0][:max_bytes_per_partition] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'max_bytes_per_partition is not integer' do
        config[:topics][0][:max_bytes_per_partition] = 's'
        expect(schema.call(config).success?).to be_falsey
      end

      it 'max_bytes_per_partition is less than 0' do
        config[:topics][0][:max_bytes_per_partition] = -1
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'start_from_beginning validator' do
      it 'start_from_beginning is nil' do
        config[:topics][0][:start_from_beginning] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'start_from_beginning is not a bool' do
        config[:topics][0][:start_from_beginning] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'controller validator' do
      it 'controller is not present' do
        config[:topics][0][:controller] = nil
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'parser validator' do
      it 'parser is not present' do
        config[:topics][0][:parser] = nil
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'interchanger validator' do
      it 'interchanger is not present' do
        config[:topics][0][:interchanger] = nil
        expect(schema.call(config).success?).to be_falsey
      end
    end

    context 'batch_processing validator' do
      it 'batch_processing is nil' do
        config[:topics][0][:batch_processing] = nil
        expect(schema.call(config).success?).to be_falsey
      end

      it 'batch_processing is not a bool' do
        config[:topics][0][:batch_processing] = 2
        expect(schema.call(config).success?).to be_falsey
      end
    end
  end
end
