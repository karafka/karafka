# frozen_string_literal: true

# When OAUTHBEARER is used, librdkafka should request a token for each consumer at its start and
# Karafka should deliver each request only to the listener for the client that asked for it.
# With two subscription groups, each consumer should get exactly one `oauthbearer.token_refresh`
# event with its own bearer and should accept the token set by the listener.
#
# The test broker has no SASL listener, so authentication fails after the token is set. This is
# expected and the only kind of errors we allow here.

class Listener
  def on_oauthbearer_token_refresh(event)
    bearer = event[:bearer]

    DT[:refreshes] << [
      bearer.class,
      bearer.name,
      bearer.oauthbearer_set_token(
        token: "jwt",
        lifetime_ms: (Time.now.to_i + 3_600) * 1_000,
        principal_name: "kafka-cluster"
      )
    ]
  end
end

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"security.protocol"] = "sasl_plaintext"
  config.kafka[:"sasl.mechanisms"] = "OAUTHBEARER"
  config.oauth.token_provider_listener = Listener.new
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << [event[:type], event[:error].code]
end

clients = {}

Karafka.monitor.subscribe("statistics.emitted") do |event|
  clients[event[:subscription_group_id]] = event[:statistics]["name"]
  DT[:statistics] << true
end

draw_routes(create_topics: false) do
  subscription_group :a do
    topic DT.topics[0] do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

# Statistics come every 100 ms, so waiting for many gives a duplicate refresh time to show up
start_karafka_and_wait_until do
  DT[:refreshes].size >= 2 &&
    clients.size >= 2 &&
    DT[:statistics].size >= 20
end

assert_equal 2, DT[:refreshes].size
assert_equal [Rdkafka::Consumer], DT[:refreshes].map(&:first).uniq
assert_equal clients.values.sort, DT[:refreshes].map { |refresh| refresh[1] }.sort
assert_equal [0], DT[:refreshes].map(&:last).uniq
assert_equal ["librdkafka.error"], DT[:errors].map(&:first).uniq
assert (DT[:errors].map(&:last).uniq - %i[authentication all_brokers_down]).empty?
