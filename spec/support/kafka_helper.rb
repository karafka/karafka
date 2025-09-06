# frozen_string_literal: true

# Helper module for configurable Kafka connection settings
# Works with both regular specs (that load integrations_helper) and pristine specs
module KafkaHelper
  # @return [String] Kafka host from environment or default
  def kafka_host
    ENV.fetch('KARAFKA_KAFKA_HOST', '127.0.0.1')
  end

  # @return [String] Kafka port from environment or default
  def kafka_port
    ENV.fetch('KARAFKA_KAFKA_PORT', '9092')
  end

  # @return [String] Full Kafka bootstrap servers string
  def kafka_bootstrap_servers
    "#{kafka_host}:#{kafka_port}"
  end

  # @return [String] Kafka bootstrap servers string for a specific port (for testing different ports)
  def kafka_bootstrap_servers_with_port(port)
    "#{kafka_host}:#{port}"
  end
end

# Add to main scope for easy access
include KafkaHelper