# frozen_string_literal: true

# Share group (KIP-932) idle housekeeping: when a poll returns no records, the listener schedules
# an idle job for each active consumer so periodic work can run even without new messages. We
# observe it via the `consumer.before_schedule_idle` instrumentation, which fires for each idle
# job once the produced records are exhausted.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

Karafka.monitor.subscribe("consumer.before_schedule_idle") do |event|
  DT[:idle] << event[:caller].object_id
end

produce_many(DT.topic, DT.uuids(5))

# Consume everything first (idle only runs for consumers that have consumed at least once), then
# keep running until empty polls start scheduling idle jobs.
start_karafka_and_wait_until do
  DT[:accepted].size >= 5 && !DT[:idle].empty?
end

assert DT[:accepted].size >= 5
assert !DT[:idle].empty?
