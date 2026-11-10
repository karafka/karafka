# frozen_string_literal: true

# Karafka::Admin.copy_dead_letter_queue without a target topic should raise for a message that
# has no source topic header (as the OSS DLQ dispatches them) and dispatch nothing.

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.producer.produce_many_sync(
  [
    { topic: DT.topics[0], payload: "0", headers: { "source_topic" => DT.topics[1] } },
    { topic: DT.topics[0], payload: "1" }
  ]
)

begin
  Karafka::Admin.copy_dead_letter_queue(DT.topics[0])
rescue Karafka::Errors::SourceTopicMissingError => e
  DT[:error] = e.message
end

assert_equal "#{DT.topics[0]}/0/1", DT[:error]
assert_equal [0, 0], Karafka::Admin.read_watermark_offsets(DT.topics[1], 0)
