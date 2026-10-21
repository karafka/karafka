# frozen_string_literal: true

# Share group (KIP-932) stop in the middle of processing batches from many partitions: consumers
# accept records one by one and bail out once the stop is requested. After a restart in the same
# process only the not yet accepted records are consumed, so every record is processed once.

setup_karafka do |config|
  config.concurrency = 3
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      if DT[:phase] == [1]
        # Leave the rest of the batch unacknowledged once the stop was requested
        break if Karafka::App.stopping?

        sleep(0.2)
        DT[:phase1] << message.raw_payload
      else
        DT[:phase2] << [message.raw_payload, message.delivery_count]
      end

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

setup_share_group(DT.topic, DT.group, 3)

elements = DT.uuids(90)

elements.each_with_index do |element, index|
  produce(DT.topic, element, partition: index % 3)
end

DT[:phase] << 1

start_karafka_and_wait_until(reset_status: true) do
  DT[:phase1].size >= 5
end

DT[:phase].clear
DT[:phase] << 2

accepted = DT[:phase1].dup

assert accepted.size < elements.size

start_karafka_and_wait_until do
  DT[:phase2].map(&:first).uniq.size >= elements.size - accepted.size
end

consumed = DT[:phase2].map(&:first)

# Accepted records are never delivered again and nothing is lost
assert (consumed & accepted).empty?
assert_equal (elements - accepted).sort, consumed.uniq.sort
# Records acquired but not processed in the first run come back with a higher delivery count
assert DT[:phase2].any? { |_, delivery_count| delivery_count >= 2 }
