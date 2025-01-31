# frozen_string_literal: true

# When we have a lot of partitions and we seek back with offset reset, it should correctly allow
# us to mark offsets per partition

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    if @seeked && !@recorded
      @recorded = true
      DT[partition] = messages.first.offset
      mark_as_consumed!(messages.first)
    elsif !@seeked
      messages.each do |message|
        mark_as_consumed!(message)

        next unless message.offset == 19

        seek(message.offset - partition)
        @seeked = true
      end
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 10)
    manual_offset_management(true)
  end
end

10.times do |i|
  produce_many(DT.topic, DT.uuids(20), partition: i)
end

PARTITIONS = (0..9).to_a

start_karafka_and_wait_until do
  PARTITIONS.to_a.all? do |i|
    DT.key?(i)
  end
end

results = Karafka::Admin.read_lags_with_offsets
cg = Karafka::App.consumer_groups.first.id
part_results = results.fetch(cg).fetch(DT.topic)

PARTITIONS.each do |i|
  assert_equal DT[i], 19 - i
  assert_equal part_results[i][:offset], 20 - i
  assert_equal part_results[i][:lag], i
end
