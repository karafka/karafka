# frozen_string_literal: true

# Share group (KIP-932) should publish async librdkafka errors of a share client via the error
# callback, attributed only to the share subscription group of that client.

setup_karafka(allow_errors: %w[librdkafka.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.groups[0] do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  share_group DT.groups[1] do
    topic DT.topics[1] do
      consumer Consumer
      # Bad port on purpose to trigger the error
      kafka("bootstrap.servers": "127.0.0.1:9090", inherit: true)
    end
  end
end

setup_share_group(DT.topics[0], DT.groups[0])

share_sgs = Karafka::App.subscription_groups.values.flatten.select { |sg| sg.group.share_group? }
good_sg = share_sgs.find { |sg| sg.group.name == DT.groups[0] }
bad_sg = share_sgs.find { |sg| sg.group.name == DT.groups[1] }

Karafka::App.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event
end

produce_many(DT.topics[0], DT.uuids(5))

start_karafka_and_wait_until do
  DT[:errors].size >= 2 && DT[:accepted].size >= 5
end

event = DT[:errors].first

assert event.is_a?(Karafka::Core::Monitoring::Event)
assert_equal "error.occurred", event.id
assert(DT[:errors].all? { |error| error[:type] == "librdkafka.error" })
assert(DT[:errors].all? { |error| error[:error].is_a?(Rdkafka::RdkafkaError) })
assert(DT[:errors].all? { |error| error[:subscription_group_id] == bad_sg.id })
assert(DT[:errors].all? { |error| error[:consumer_group_id] == bad_sg.group.id })
assert(DT[:errors].all? { |error| error[:group_id] == bad_sg.group.id })
assert(DT[:errors].none? { |error| error[:subscription_group_id] == good_sg.id })
# Each error published only once
assert_equal DT[:errors].size, DT[:errors].map { |error| error[:error] }.uniq(&:object_id).size
