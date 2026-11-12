# frozen_string_literal: true

# Karafka CLI info --extended should redact sensitive kafka config values, also in topic overrides

output = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(output)
  config.kafka[:"sasl.password"] = "root-sasl-password"
  config.kafka[:"ssl.key.pem"] = "root-private-key-pem"
  config.kafka[:"ssl.certificate.pem"] = "root-certificate-pem"
end

draw_routes(create_topics: false) do
  topic :secret_topic do
    consumer Class.new(Karafka::BaseConsumer)
    kafka(inherit: true, "sasl.password": "topic-sasl-password")
  end
end

ARGV[0] = "info"
ARGV[1] = "--extended"

Karafka::Cli.start

results = output.string

assert results.include?("sasl.password: [REDACTED]")
assert results.include?("ssl.key.pem: [REDACTED]")
assert results.include?("ssl.certificate.pem: root-certificate-pem")
assert results.match?(/kafka overrides:.*sasl\.password.*\[REDACTED\]/)

%w[root-sasl-password root-private-key-pem topic-sasl-password].each do |secret|
  assert !results.include?(secret), secret
end
