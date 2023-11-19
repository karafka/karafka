# frozen_string_literal: true

# When we exceed max poll interval but did not poll yet, the async and sync offset commits should
# give us accurate representation of the ownership because of lost assignment check.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    sleep(11)

    DT[:results] << commit_offsets
    DT[:results] << commit_offsets!
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topics[0], DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal DT[:results], [false, false]
