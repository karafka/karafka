# frozen_string_literal: true

# When several consumers process slices of the same partition (a custom partitioner, like Pro
# virtual partitions), their acknowledgements are flushed once all of them settled. Flushing per
# slice queues several async commits for the same partition and librdkafka merges their
# acknowledgements out of order, which the broker rejects with `invalid_request`.

class RoundRobinSlices < Karafka::Processing::ShareGroups::Partitioner
  def call(_topic, messages, _coordinator)
    messages.each_with_index.group_by { |_, i| i % 4 }.each do |key, pairs|
      yield(key, pairs.map(&:first))
    end
  end
end

setup_karafka(allow_errors: false) do |config|
  config.concurrency = 4
  config.internal.processing.share_groups.partitioner_class = RoundRobinSlices
end

class Consumer < Karafka::ShareConsumer
  def consume
    sleep(1)

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

setup_share_group(DT.topic, DT.group, 2)

elements = DT.uuids(40)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 40 && sleep(3)
end

assert_equal elements.sort, DT[:accepted].uniq.sort
assert_equal 40, DT[:accepted].size
