# frozen_string_literal: true

# Share group (KIP-932) topic whose consumption fails a couple of times does not block other
# topics of the share group, even with a single worker: their records are processed by the same
# worker in the meantime, while the failing records are released, redelivered and processed once
# the errors stop.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 1
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event
end

class Consumer1 < Karafka::ShareConsumer
  def consume
    @count ||= 0
    @count += 1

    raise StandardError if @count < 3

    messages.each do |message|
      DT[0] << message.raw_payload
      DT[:all] << message.raw_payload
      mark_as_accepted(message)
    end

    DT[1] << Thread.current.object_id
  end
end

class Consumer2 < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[2] << message.raw_payload
      DT[:all] << message.raw_payload
      mark_as_accepted(message)
    end

    DT[3] << Thread.current.object_id
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer1
    end

    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

elements1 = DT.uuids(10)
elements2 = DT.uuids(10)

produce_many(DT.topics[0], elements1)
produce_many(DT.topics[1], elements2)

start_karafka_and_wait_until do
  DT[:all].size >= 20
end

assert_equal 2, DT[:errors].size
assert_equal StandardError, DT[:errors].first[:error].class
assert_equal "consumer.consume.error", DT[:errors].first[:type]
assert_equal elements1.sort, DT[0].sort
assert_equal elements2.sort, DT[2].sort
# Same worker from the same thread should process both
assert_equal 1, (DT[1] + DT[3]).uniq.size
assert_equal 20, DT[:all].size
