# frozen_string_literal: true

# Share group (KIP-932) acknowledgements from many threads at once. The share consumer allows
# only one caller at a time, so a record acknowledged while another thread is in a synchronous
# commit must wait instead of failing with `conflict`. Here each batch is processed by two
# threads: one commits after every record while the other keeps acknowledging at the same time.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    committing, acknowledging = messages.to_a.partition.with_index { |_, index| index.even? }

    [
      Thread.new { committing.each { |message| mark_as_accepted!(message) } },
      Thread.new { acknowledging.each { |message| mark_as_accepted(message) } }
    ].each(&:join)

    messages.each { |message| DT[:accepted] << message.raw_payload }
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

elements = DT.uuids(1_000)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 1_000
end

assert_equal elements.sort, DT[:accepted].uniq.sort
