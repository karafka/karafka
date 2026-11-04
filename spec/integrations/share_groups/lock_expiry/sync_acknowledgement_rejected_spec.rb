# frozen_string_literal: true

# Share group (KIP-932) synchronous acknowledgement of a record whose acquisition lock expired:
# `#mark_as_accepted!` returns false as the broker rejects it, the record is delivered again and
# then it is accepted (returning true).

setup_karafka(allow_errors: %w[connection.client.acknowledgement.error])

class Consumer < Karafka::ShareConsumer
  def consume
    message = messages.first

    # Process the first delivery longer than the 15 seconds lock
    sleep(20) if message.delivery_count == 1

    DT[:results] << [message.delivery_count, mark_as_accepted!(message)]
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(configs: { "share.record.lock.duration.ms" => "15000" })

produce(DT.topic, "a")

start_karafka_and_wait_until do
  DT[:results].any? { |_, result| result }
end

assert_equal [1, false], DT[:results].first
assert_equal [2, true], DT[:results].last
