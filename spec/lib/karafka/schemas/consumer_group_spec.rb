# frozen_string_literal: true

RSpec.describe Karafka::Schemas::ConsumerGroup do
  let(:schema) { described_class }

  let(:topics) do
    [
      {
        id: 'id',
        name: 'name',
        backend: :inline,
        consumer: Class.new,
        parser: Class.new,
        max_bytes_per_partition: 1,
        start_from_beginning: true,
        batch_consuming: true,
        persistent: false
      }
    ]
  end
  let(:config) do
    {
      id: 'id',
      topic_mapper: Karafka::Routing::TopicMapper,
      seed_brokers: ['kafka://localhost:9092'],
      offset_commit_interval: 1,
      offset_commit_threshold: 1,
      heartbeat_interval: 1,
      session_timeout: 1,
      ssl_ca_cert: 'ca_cert',
      ssl_client_cert: 'client_cert',
      ssl_client_cert_key: 'client_cert_key',
      ssl_ca_certs_from_system: true,
      max_bytes_per_partition: 1_048_576,
      offset_retention_time: 1000,
      fetcher_max_queue_size: 100,
      start_from_beginning: true,
      connect_timeout: 10,
      socket_timeout: 10,
      pause_timeout: 10,
      max_wait_time: 10,
      batch_fetching: true,
      topics: topics,
      min_bytes: 1,
      max_bytes: 2048
    }
  end

  context 'when config is valid' do
    it { expect(schema.call(config)).to be_success }
  end

  context 'when topics is an empty array' do
    before { config[:topics] = [] }

    it { expect(schema.call(config)).not_to be_success }
  end

  context 'when topics is not an array' do
    before { config[:topics] = nil }

    it { expect(schema.call(config)).not_to be_success }
  end

  context 'when we validate id' do
    context 'when id is nil' do
      before { config[:id] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when id is not a string' do
      before { config[:id] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when id is an invalid string' do
      before { config[:id] = '%^&*(' }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate seed_brokers' do
    context 'when seed_brokers is nil' do
      before { config[:seed_brokers] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when seed_brokers is an empty array' do
      before { config[:seed_brokers] = [] }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when seed_brokers is not an array' do
      before { config[:seed_brokers] = 'timeout' }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when seed_broker does not have a proper uri schema' do
      before { config[:seed_brokers] = ['https://github.com/karafka:80'] }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when seed_broker does not have a port defined' do
      before { config[:seed_brokers] = ['kafka://github.com/karafka'] }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when seed_broker is not an uri' do
      before { config[:seed_brokers] = ['#$%^&*()'] }

      it { expect(schema.call(config)).not_to be_success }
      it { expect { schema.call(config).errors }.not_to raise_error }
    end

    %w[
      kafka+ssl
      kafka
      plaintext
      ssl
    ].each do |schema_prefix|
      context "when seed_broker is a #{schema_prefix} one" do
        before { config[:seed_brokers] = ["#{schema_prefix}://localhost:9092"] }

        it { expect(schema.call(config)).to be_success }
      end
    end
  end

  context 'when we validate session_timeout' do
    context 'when session_timeout is nil' do
      before { config[:session_timeout] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when session_timeout is not integer' do
      before { config[:session_timeout] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate offset_commit_interval' do
    context 'when offset_commit_interval is nil' do
      before { config[:offset_commit_interval] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when offset_commit_interval is not integer' do
      before { config[:offset_commit_interval] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate offset_commit_threshold' do
    context 'when offset_commit_threshold is nil' do
      before { config[:offset_commit_threshold] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when offset_commit_threshold is not integer' do
      before { config[:offset_commit_threshold] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate offset_retention_time' do
    context 'when offset_retention_time is not integer' do
      before { config[:offset_retention_time] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate fetcher_max_queue_size' do
    context 'when fetcher_max_queue_size is nil' do
      before { config[:fetcher_max_queue_size] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when fetcher_max_queue_size is not integer' do
      before { config[:fetcher_max_queue_size] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when fetcher_max_queue_size is 0' do
      before { config[:fetcher_max_queue_size] = 0 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when fetcher_max_queue_size is less than 0' do
      before { config[:fetcher_max_queue_size] = -1 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate heartbeat_interval' do
    context 'when heartbeat_interval is nil' do
      before { config[:heartbeat_interval] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when heartbeat_interval is not integer' do
      before { config[:heartbeat_interval] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate connect_timeout' do
    context 'when connect_timeout is nil' do
      before { config[:connect_timeout] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when connect_timeout is not integer' do
      before { config[:connect_timeout] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when connect_timeout is 0' do
      before { config[:connect_timeout] = 0 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when connect_timeout is less than 0' do
      before { config[:connect_timeout] = -1 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate pause_timeout' do
    context 'when pause_timeout is nil' do
      before { config[:pause_timeout] = nil }

      it { expect(schema.call(config)).to be_success }
    end

    context 'when pause_timeout is not integer' do
      before { config[:pause_timeout] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when pause_timeout is 0' do
      before { config[:pause_timeout] = 0 }

      it { expect(schema.call(config)).to be_success }
    end

    context 'when pause_timeout is less than 0' do
      before { config[:pause_timeout] = -1 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate socket_timeout' do
    context 'when socket_timeout is nil' do
      before { config[:socket_timeout] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when socket_timeout is not integer' do
      before { config[:socket_timeout] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when socket_timeout is 0' do
      before { config[:socket_timeout] = 0 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when socket_timeout is less than 0' do
      before { config[:socket_timeout] = -1 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate max_wait_time' do
    context 'when max_wait_time is nil' do
      before { config[:max_wait_time] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when max_wait_time is not integer' do
      before { config[:max_wait_time] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when max_wait_time is less than 0' do
      before { config[:max_wait_time] = -1 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate min_bytes' do
    context 'when min_bytes is nil' do
      before { config[:min_bytes] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when min_bytes is not integer' do
      before { config[:min_bytes] = 's' }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when min_bytes is less than 1' do
      before { config[:min_bytes] = 0 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when min_bytes is a float' do
      before { config[:min_bytes] = rand(100) + 0.1 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate batch_fetching' do
    context 'when batch_fetching is nil' do
      before { config[:batch_fetching] = nil }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when batch_fetching is not a bool' do
      before { config[:batch_fetching] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when max_wait_time is bigger than socket_timeout' do
    before do
      config[:max_wait_time] = 2
      config[:socket_timeout] = 1
    end

    it { expect(schema.call(config)).not_to be_success }
  end

  %i[
    ssl_ca_cert
    ssl_ca_cert_file_path
    ssl_client_cert
    ssl_client_cert_key
    sasl_gssapi_principal
    sasl_gssapi_keytab
    sasl_plain_authzid
    sasl_plain_username
    sasl_plain_password
    sasl_scram_username
    sasl_scram_password
    sasl_scram_mechanism
  ].each do |encryption_attribute|
    context "when we validate #{encryption_attribute}" do
      context "when #{encryption_attribute} is nil" do
        before { config[encryption_attribute] = nil }

        it { expect(schema.call(config)).to be_success }
      end

      context "when #{encryption_attribute} is not a string" do
        before { config[encryption_attribute] = 2 }

        it { expect(schema.call(config)).not_to be_success }
      end
    end
  end

  context 'when we validate ssl_ca_certs_from_system' do
    context 'when ssl_ca_certs_from_system is not a bool' do
      before { config[:ssl_ca_certs_from_system] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end
  end

  context 'when we validate sasl_scram_mechanism' do
    context 'when sasl_scram_mechanism is nil' do
      before { config[:sasl_scram_mechanism] = nil }

      it { expect(schema.call(config)).to be_success }
    end

    context 'when sasl_scram_mechanism is not a string' do
      before { config[:sasl_scram_mechanism] = 2 }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when sasl_scram_mechanism is an invalid string' do
      before { config[:sasl_scram_mechanism] = rand.to_s }

      it { expect(schema.call(config)).not_to be_success }
    end

    context 'when sasl_scram_mechanism is sha256' do
      before { config[:sasl_scram_mechanism] = 'sha256' }

      it { expect(schema.call(config)).to be_success }
    end

    context 'when sasl_scram_mechanism is sha512' do
      before { config[:sasl_scram_mechanism] = 'sha512' }

      it { expect(schema.call(config)).to be_success }
    end
  end
end
