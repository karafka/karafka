# frozen_string_literal: true

# Karafka CLI info --extended should print share groups (KIP-932) alongside consumer groups: the
# share groups count, the share group with its subscription groups and topics, and the share
# topic features (acknowledgements and dead letter queue).

setup_karafka

draw_routes(create_topics: false) do
  consumer_group :integration_group do
    topic :integration_topic do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group :integration_share_group do
    topic :integration_share_topic do
      consumer Class.new(Karafka::ShareConsumer)
      acknowledgements(unacknowledged: :reject)
      dead_letter_queue(topic: "share_dlq_target", max_retries: 2)
    end
  end
end

ARGV.replace(%w[info --extended])

output = StringIO.new
Karafka.instance_variable_set(:@logger, ::Logger.new(output).tap { |l| l.level = ::Logger::INFO })

Karafka::Cli.start

ARGV.clear

results = output.string

assert results.include?("Consumer groups count: 1"), results
assert results.include?("Share groups count: 1"), results
assert results.include?("Subscription groups count: 2"), results

assert results.include?("Consumer group: integration_group (active)"), results
assert results.include?("Share group: integration_share_group (active)"), results
assert results.include?("kafka[group.id]: integration_share_group"), results
assert results.include?("Topic: integration_share_topic (active)"), results

# Share topic features should be detected and printed
assert results.include?("Features:"), results
assert results.include?("acknowledgements: unacknowledged=:reject"), results
assert results.include?("dead_letter_queue:"), results
assert results.include?("share_dlq_target"), results
