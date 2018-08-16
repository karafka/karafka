# frozen_string_literal: true

RSpec.describe Karafka::Connection::Builder do
  subject(:builder) { described_class }

  describe '.call' do
    let(:kafka_client) { instance_double(Kafka::Client) }
    let(:kafka_client_args) do
      [
        ::Karafka::App.config.kafka.seed_brokers,
        logger: ::Karafka.logger,
        client_id: ::Karafka::App.config.client_id,
        socket_timeout: 30,
        connect_timeout: 10,
        sasl_plain_authzid: '',
        ssl_ca_certs_from_system: false,
        sasl_over_ssl: true
      ]
    end

    it 'expect to build proper instance' do
      expect(Kafka).to receive(:new).with(*kafka_client_args).and_return(kafka_client)
      expect(builder.call).to eq kafka_client
    end
  end
end
