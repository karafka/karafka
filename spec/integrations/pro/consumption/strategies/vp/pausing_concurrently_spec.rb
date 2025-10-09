# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we invoke pause from multiple VPs, the last one should win

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 500
end

DT[:in_progress] = 0

class Consumer < Karafka::BaseConsumer
  def consume
    synchronize { DT[:in_progress] += 1 }

    messages.each { |message| DT[0] << message.offset }

    if DT[:in_progress] > 1
      sleep(5)

      synchronize do
        # This should be overwritten with above, doing that twice to check, that the last one
        # is selected for target pausing
        pause(0, 5_000)
        pause_offset = messages.first.offset + 5
        DT[:pauses] << [pause_offset, Time.now.to_f]
        pause(pause_offset, 5_000)
      end
    end

    sleep(5)

    synchronize { DT[:in_progress] -= 1 }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(1000))

start_karafka_and_wait_until do
  DT[0].size >= 1000
end

current_time = DT[:pauses].first.last

groups = Array.new(100) { [] }
group = 0

DT[:pauses].each do |pause|
  group += 1 unless ((current_time - 3)..(current_time + 3)).cover?(pause.last)

  groups[group] << pause.first

  current_time = pause.last
end

first = groups.delete_if(&:empty?).map(&:last).first

# No messages before the first pause should ever be processed again

DT[0]
  .sort
  .select { |offset| offset < first }
  .group_by(&:itself)
  .values
  .map(&:size)
  .all?(1)
  .then { |no_duplicates| assert no_duplicates }
