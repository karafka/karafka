# frozen_string_literal: true

# Share group (KIP-932) batches of different partitions run in parallel on many workers, while
# thread-local data, consumer instance state and mutex guarded shared state stay consistent.

setup_karafka do |config|
  config.concurrency = 5
end

class SharedStore
  def initialize
    @counter = 0
    @mutex = Mutex.new
  end

  def increment(amount)
    @mutex.synchronize do
      before = @counter
      # Give other threads a chance to interleave
      sleep(0.001)
      @counter = before + amount
    end
  end

  def counter
    @mutex.synchronize { @counter }
  end
end

STORE = SharedStore.new

class Consumer < Karafka::ShareConsumer
  def consume
    @partitions ||= []
    @partitions << messages.metadata.partition

    messages.each do |message|
      data = JSON.parse(message.raw_payload)

      Thread.current[:karafka_test_data] = data["id"]
      @current = data["id"]

      STORE.increment(data["amount"])
      sleep(rand / 100)

      DT[:errors] << "thread-local corruption" unless Thread.current[:karafka_test_data] == data["id"]
      DT[:errors] << "instance corruption" unless @current == data["id"]

      DT[:consumed] << data["id"]
      DT[:threads] << Thread.current.object_id
      mark_as_accepted(message)

      Thread.current[:karafka_test_data] = nil
    end

    # Each consumer instance handles one partition only
    DT[:errors] << "partition mixing" unless @partitions.uniq.size == 1
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topic, DT.group, 5)

ids = []

5.times do |partition|
  payloads = Array.new(20) do |i|
    id = "#{partition}-#{i}"
    ids << id
    { id: id, amount: i }.to_json
  end

  produce_many(DT.topic, payloads, partition: partition)
end

start_karafka_and_wait_until do
  DT[:consumed].uniq.size >= ids.size
end

assert DT[:errors].empty?, DT[:errors]
assert_equal ids.sort, DT[:consumed].uniq.sort
assert DT[:threads].uniq.size > 1
# Accepted records are not redelivered, so the counter matches the produced amounts exactly
assert_equal ids.size, DT[:consumed].size
assert_equal 5 * (0..19).sum, STORE.counter
