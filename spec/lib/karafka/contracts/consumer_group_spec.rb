# frozen_string_literal: true

RSpec.describe Karafka::Contracts::ConsumerGroup do
  subject(:check) { described_class.new.call(config) }

  let(:topics) do
    [
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
    ]
  end
  let(:pause_details) do
    {
      pause_timeout: 10,
      pause_max_timeout: nil,
      pause_exponential_backoff: false
    }
  end
  let(:ssl_details) do
    {
      ssl_ca_cert: File.read("#{CERTS_PATH}/ca.crt"),
      ssl_ca_cert_file_path: "#{CERTS_PATH}/ca.crt",
      ssl_client_cert: File.read("#{CERTS_PATH}/rsa/client.crt"),
      ssl_client_cert_key: File.read("#{CERTS_PATH}/rsa/valid.key"),
      ssl_ca_certs_from_system: true,
      ssl_client_cert_chain: File.read("#{CERTS_PATH}/client.chain"),
      sasl_over_ssl: true
    }
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
      max_bytes_per_partition: 1_048_576,
      offset_retention_time: 1000,
      fetcher_max_queue_size: 100,
      assignment_strategy: Karafka::AssignmentStrategies::RoundRobin.new,
      start_from_beginning: true,
      connect_timeout: 10,
      reconnect_timeout: 10,
      socket_timeout: 10,
      max_wait_time: 10,
      batch_fetching: true,
      topics: topics,
      min_bytes: 1,
      max_bytes: 2048
    }.merge(pause_details).merge(ssl_details)
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when we validate topics' do
    context 'when topics is an empty array' do
      before { config[:topics] = [] }

      it { expect(check).not_to be_success }
    end

    context 'when topics is not an array' do
      before { config[:topics] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when topics names are not unique' do
      before { config[:topics][1] = config[:topics][0].dup }

      it { expect(check).not_to be_success }
      it { expect { check.errors }.not_to raise_error }
    end

    context 'when topics names are unique' do
      before do
        config[:topics][1] = config[:topics][0].dup
        config[:topics][1][:name] = rand.to_s
      end

      it { expect(check).to be_success }
    end

    context 'when topics do not comply with the internal contract' do
      before do
        config[:topics][1] = config[:topics][0].dup
        config[:topics][1][:name] = nil
      end

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate id' do
    context 'when id is nil' do
      before { config[:id] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when id is not a string' do
      before { config[:id] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when id is an invalid string' do
      before { config[:id] = '%^&*(' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate seed_brokers' do
    context 'when seed_brokers is nil' do
      before { config[:seed_brokers] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when seed_brokers is an empty array' do
      before { config[:seed_brokers] = [] }

      it { expect(check).not_to be_success }
    end

    context 'when seed_brokers is not an array' do
      before { config[:seed_brokers] = 'timeout' }

      it { expect(check).not_to be_success }
    end

    context 'when seed_broker does not have a proper uri contract' do
      before { config[:seed_brokers] = ['https://github.com/karafka:80'] }

      it { expect(check).not_to be_success }
    end

    context 'when seed_broker does not have a port defined' do
      before { config[:seed_brokers] = ['kafka://github.com/karafka'] }

      it { expect(check).not_to be_success }
    end

    context 'when seed_broker is not an uri' do
      before { config[:seed_brokers] = ['#$%^&*()'] }

      it { expect(check).not_to be_success }
      it { expect { check.errors }.not_to raise_error }
    end

    %w[
      kafka+ssl
      kafka
      plaintext
      ssl
    ].each do |contract_prefix|
      context "when seed_broker is a #{contract_prefix} one" do
        before { config[:seed_brokers] = ["#{contract_prefix}://localhost:9092"] }

        it { expect(check).to be_success }
      end
    end
  end

  context 'when we validate session_timeout' do
    context 'when session_timeout is nil' do
      before { config[:session_timeout] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when session_timeout is not integer' do
      before { config[:session_timeout] = 's' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate offset_commit_interval' do
    context 'when offset_commit_interval is nil' do
      before { config[:offset_commit_interval] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when offset_commit_interval is not integer' do
      before { config[:offset_commit_interval] = 's' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate offset_commit_threshold' do
    context 'when offset_commit_threshold is nil' do
      before { config[:offset_commit_threshold] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when offset_commit_threshold is not integer' do
      before { config[:offset_commit_threshold] = 's' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate offset_retention_time' do
    context 'when offset_retention_time is not integer' do
      before { config[:offset_retention_time] = 's' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate fetcher_max_queue_size' do
    context 'when fetcher_max_queue_size is nil' do
      before { config[:fetcher_max_queue_size] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when fetcher_max_queue_size is not integer' do
      before { config[:fetcher_max_queue_size] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when fetcher_max_queue_size is 0' do
      before { config[:fetcher_max_queue_size] = 0 }

      it { expect(check).not_to be_success }
    end

    context 'when fetcher_max_queue_size is less than 0' do
      before { config[:fetcher_max_queue_size] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate rebalance_timeout' do
    context 'when rebalance_timeout is nil' do
      before { config[:rebalance_timeout] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when rebalance_timeout is not integer' do
      before { config[:rebalance_timeout] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when rebalance_timeout is 0' do
      before { config[:rebalance_timeout] = 0 }

      it { expect(check).not_to be_success }
    end

    context 'when rebalance_timeout is less than 0' do
      before { config[:rebalance_timeout] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate assignment_strategy' do
    context 'when it is an object without call method' do
      before { config[:assignment_strategy] = Struct.new(:test).new }

      it { expect(check).to be_failure }
      it { expect { check.errors }.not_to raise_error }
    end

    context 'when it is an object with call method' do
      before { config[:assignment_strategy] = Struct.new(:call).new }

      it { expect(check).to be_success }
    end
  end

  context 'when we validate heartbeat_interval' do
    context 'when heartbeat_interval is nil' do
      before { config[:heartbeat_interval] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when heartbeat_interval is not integer' do
      before { config[:heartbeat_interval] = 's' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate connect_timeout' do
    context 'when connect_timeout is nil' do
      before { config[:connect_timeout] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when connect_timeout is not integer' do
      before { config[:connect_timeout] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when connect_timeout is 0' do
      before { config[:connect_timeout] = 0 }

      it { expect(check).not_to be_success }
    end

    context 'when connect_timeout is less than 0' do
      before { config[:connect_timeout] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate pause_timeout' do
    context 'when pause_timeout is nil' do
      before { config[:pause_timeout] = nil }

      it { expect(check).to be_success }
    end

    context 'when pause_timeout is not integer' do
      before { config[:pause_timeout] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when pause_timeout is 0' do
      before { config[:pause_timeout] = 0 }

      it { expect(check).to be_success }
    end

    context 'when pause_timeout is less than 0' do
      before { config[:pause_timeout] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate pause_max_timeout' do
    context 'when pause_max_timeout is nil' do
      before { config[:pause_max_timeout] = nil }

      it { expect(check).to be_success }
    end

    context 'when pause_max_timeout is not integer' do
      before { config[:pause_max_timeout] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when pause_max_timeout is 0' do
      before { config[:pause_max_timeout] = 0 }

      it { expect(check).to be_success }
    end

    context 'when pause_max_timeout is less than 0' do
      before { config[:pause_max_timeout] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate pause_exponential_backoff' do
    context 'when pause_exponential_backoff is not a bool' do
      before { config[:pause_exponential_backoff] = 2 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we use pause_exponential_backoff' do
    before do
      config[:pause_exponential_backoff] = true
      config[:pause_timeout] = pause_timeout
      config[:pause_max_timeout] = pause_max_timeout
    end

    context 'when the pause_timeout is more than pause_max_timeout' do
      let(:pause_timeout) { 10 }
      let(:pause_max_timeout) { pause_timeout - 1 }

      it { expect(check).not_to be_success }
    end

    context 'when pause_timeout is same as pause_max_timeout' do
      let(:pause_timeout) { 10 }
      let(:pause_max_timeout) { pause_timeout }

      it { expect(check).to be_success }
    end

    context 'when pause_timeout is less than pause_max_timeout' do
      let(:pause_timeout) { 10 }
      let(:pause_max_timeout) { pause_timeout + 1 }

      it { expect(check).to be_success }
    end
  end

  context 'when we dont use pause_exponential_backoff' do
    before do
      config[:pause_exponential_backoff] = false
      config[:pause_timeout] = pause_timeout
      config[:pause_max_timeout] = pause_max_timeout
    end

    context 'when the pause_timeout is more than pause_max_timeout' do
      let(:pause_timeout) { 10 }
      let(:pause_max_timeout) { pause_timeout - 1 }

      it { expect(check).to be_success }
    end

    context 'when pause_timeout is same as pause_max_timeout' do
      let(:pause_timeout) { 10 }
      let(:pause_max_timeout) { pause_timeout }

      it { expect(check).to be_success }
    end

    context 'when pause_timeout is less than pause_max_timeout' do
      let(:pause_timeout) { 10 }
      let(:pause_max_timeout) { pause_timeout + 1 }

      it { expect(check).to be_success }
    end
  end

  context 'when we validate socket_timeout' do
    context 'when socket_timeout is nil' do
      before { config[:socket_timeout] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when socket_timeout is not integer' do
      before { config[:socket_timeout] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when socket_timeout is 0' do
      before { config[:socket_timeout] = 0 }

      it { expect(check).not_to be_success }
    end

    context 'when socket_timeout is less than 0' do
      before { config[:socket_timeout] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate max_wait_time' do
    context 'when max_wait_time is nil' do
      before { config[:max_wait_time] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when max_wait_time is not integer' do
      before { config[:max_wait_time] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when max_wait_time is less than 0' do
      before { config[:max_wait_time] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate min_bytes' do
    context 'when min_bytes is nil' do
      before { config[:min_bytes] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when min_bytes is not integer' do
      before { config[:min_bytes] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when min_bytes is less than 1' do
      before { config[:min_bytes] = 0 }

      it { expect(check).not_to be_success }
    end

    context 'when min_bytes is a float' do
      before { config[:min_bytes] = rand(100) + 0.1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate batch_fetching' do
    context 'when batch_fetching is nil' do
      before { config[:batch_fetching] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when batch_fetching is not a bool' do
      before { config[:batch_fetching] = 2 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when max_wait_time is bigger than socket_timeout' do
    before do
      config[:max_wait_time] = 2
      config[:socket_timeout] = 1
    end

    it { expect(check).not_to be_success }
  end

  %i[
    ssl_ca_cert
    ssl_ca_cert_file_path
    sasl_gssapi_principal
    sasl_gssapi_keytab
    sasl_plain_authzid
    sasl_plain_username
    sasl_plain_password
    sasl_scram_username
    sasl_scram_password
    sasl_scram_mechanism
    ssl_client_cert_chain
    ssl_client_cert_key_password
  ].each do |encryption_attribute|
    context "when we validate #{encryption_attribute}" do
      context "when #{encryption_attribute} is nil" do
        before { config[encryption_attribute] = nil }

        it { expect(check).to be_success }
      end

      context "when #{encryption_attribute} is not a string" do
        before { config[encryption_attribute] = 2 }

        it { expect(check).not_to be_success }
      end
    end
  end

  context 'when ssl_ca_cert_file_path does not exist' do
    before { config[:ssl_ca_cert_file_path] = rand.to_s }

    it { expect(check).not_to be_success }
  end

  context 'when ssl_ca_cert is invalid' do
    before { config[:ssl_ca_cert] = rand.to_s }

    it { expect(check).not_to be_success }
  end

  context 'when we validate ssl_client_cert' do
    context 'when ssl_client_cert is nil and ssl_client_cert_key is nil' do
      before do
        config[:ssl_client_cert] = nil
        config[:ssl_client_cert_key] = nil
        config[:ssl_client_cert_chain] = nil
      end

      it { expect(check).to be_success }
    end

    context 'when ssl_client_cert is nil and ssl_client_cert_key is not nil' do
      before { config[:ssl_client_cert] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when ssl_client_cert is not a string' do
      before { config[:ssl_client_cert] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when ssl_client_cert is a invalid string' do
      before { config[:ssl_client_cert] = 'invalid' }

      it { expect(check).not_to be_success }
      it { expect(check.errors.to_h.key?(:ssl_client_cert)).to eq true }
    end
  end

  context 'when we validate ssl_client_cert_key' do
    context 'with nil and ssl_client_cert is nil' do
      before do
        config[:ssl_client_cert] = nil
        config[:ssl_client_cert_key] = nil
        config[:ssl_client_cert_chain] = nil
      end

      it { expect(check).to be_success }
    end

    context 'with nil and ssl_client_cert is not nil' do
      before { config[:ssl_client_cert_key] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when it is not a string' do
      before { config[:ssl_client_cert_key] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when it is a invalid string' do
      before { config[:ssl_client_cert_key] = 'invalid' }

      it { expect(check).not_to be_success }
      it { expect(check.errors.to_h.key?(:ssl_client_cert_key)).to eq true }
    end

    context 'when it is a valid RSA' do
      before do
        config[:ssl_client_cert_key] = File.read("#{CERTS_PATH}/rsa/valid.key")
      end

      it { expect(check).to be_success }
    end

    context 'when it is a broken RSA' do
      before do
        config[:ssl_client_cert_key] = File.read("#{CERTS_PATH}/rsa/broken.key")
      end

      it { expect(check).not_to be_success }
    end

    context 'when it is a valid DSA' do
      before do
        config[:ssl_client_cert_key] = File.read("#{CERTS_PATH}/dsa/valid.key")
      end

      it { expect(check).to be_success }
    end

    context 'when it is a broken DSA' do
      before do
        config[:ssl_client_cert_key] = File.read("#{CERTS_PATH}/dsa/broken.key")
      end

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate ssl_client_cert_chain' do
    context 'with nil and ssl_client_cert is nil' do
      before do
        config[:ssl_client_cert_chain] = nil
        config[:ssl_client_cert] = nil
        config[:ssl_client_cert_key] = nil
      end

      it { expect(check).to be_success }
    end

    context 'when it is present but ssl_client_cert is nil' do
      before { config[:ssl_client_cert] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when it is present but ssl_client_cert_key is nil' do
      before { config[:ssl_client_cert_key] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when it is not a string' do
      before { config[:ssl_client_cert_chain] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when it is a invalid string' do
      before { config[:ssl_client_cert_chain] = 'invalid' }

      it { expect(check).not_to be_success }
      it { expect(check.errors.to_h.key?(:ssl_client_cert_chain)).to eq true }
    end
  end

  context 'when we validate ssl_client_cert_key_password' do
    context 'with nil and ssl_client_cert is nil' do
      before do
        config[:ssl_client_cert] = nil
        config[:ssl_client_cert_key] = nil
        config[:ssl_client_cert_key_password] = nil
        config[:ssl_client_cert_chain] = nil
      end

      it { expect(check).to be_success }
    end

    context 'when it is present but ssl_client_cert is nil' do
      before do
        config[:ssl_client_cert] = nil
        config[:ssl_client_cert_key_password] = 'password'
      end

      it { expect(check).not_to be_success }
    end

    context 'when it is present but ssl_client_cert_key is nil' do
      before do
        config[:ssl_client_cert_key] = nil
        config[:ssl_client_cert_key_password] = 'password'
      end

      it { expect(check).not_to be_success }
    end

    context 'when it is not a string' do
      before { config[:ssl_client_cert_key_password] = 2 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate ssl_verify_hostname' do
    context 'when it is not a bool' do
      before { config[:ssl_verify_hostname] = 2 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate ssl_ca_certs_from_system' do
    context 'when it is not a bool' do
      before { config[:ssl_ca_certs_from_system] = 2 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate sasl_over_ssl' do
    context 'when it is not a bool' do
      before { config[:sasl_over_ssl] = 2 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate sasl_scram_mechanism' do
    context 'with nil' do
      before { config[:sasl_scram_mechanism] = nil }

      it { expect(check).to be_success }
    end

    context 'when it is not a string' do
      before { config[:sasl_scram_mechanism] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when it is an invalid string' do
      before { config[:sasl_scram_mechanism] = rand.to_s }

      it { expect(check).not_to be_success }
    end

    context 'when it is sha256' do
      before { config[:sasl_scram_mechanism] = 'sha256' }

      it { expect(check).to be_success }
    end

    context 'when it is sha512' do
      before { config[:sasl_scram_mechanism] = 'sha512' }

      it { expect(check).to be_success }
    end
  end

  context 'when we validate sasl_oauth_token_provider' do
    context 'with nil' do
      before { config[:sasl_oauth_token_provider] = nil }

      it { expect(check).to be_success }
    end

    context 'when it is an object without token method' do
      before { config[:sasl_oauth_token_provider] = Struct.new(:test).new }

      it { expect(check).to be_failure }
      it { expect { check.errors }.not_to raise_error }
    end

    context 'when it is an object with token method' do
      before { config[:sasl_oauth_token_provider] = Struct.new(:token).new }

      it { expect(check).to be_success }
    end
  end
end
