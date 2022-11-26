# frozen_string_literal: true

# When using Pro, we should be able to redefine and change the whole partitioner and use our own
# custom one without any problems.

# This spec illustrated, that you can overwrite the core partitioner and use your own that
# distributes work differently for different topics with awareness of the received batch size.

SPECIAL_TOPIC = DT.topics[0]
REGULAR_TOPIC = DT.topics[1]

# Load pro components without the setup as we want to do the setup later
# This simulates normal flow where karafka loads pro when license is detected
become_pro!

class CustomPartitioner < Karafka::Pro::Processing::Partitioner
  def call(topic_name, messages, &block)
    if topic_name == SPECIAL_TOPIC
      balanced_strategy(messages, &block)
    else
      super
    end
  end

  private

  def balanced_strategy(messages)
    messages.each_slice(20).with_index do |slice, index|
      yield(index, slice)
    end
  end
end

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 500
  config.max_wait_time = 5_000
  config.initial_offset = 'earliest'
  config.internal.processing.partitioner_class = CustomPartitioner
end

assert_equal Karafka::App.config.internal.processing.partitioner_class, CustomPartitioner

class Consumer < Karafka::BaseConsumer
  def consume
    DT[topic.name] << messages.count
  end
end

draw_routes do
  topic SPECIAL_TOPIC do
    consumer Consumer

    # Can be set up without any arguments as the virtualization is delegated to the
    # CustomPartitioner
    virtual_partitions
  end

  topic REGULAR_TOPIC do
    consumer Consumer
  end
end

10.times do
  produce_many(SPECIAL_TOPIC, DT.uuids(1_000))
end

produce_many(REGULAR_TOPIC, DT.uuids(1_000))

start_karafka_and_wait_until do
  DT[SPECIAL_TOPIC].sum >= 5_000 &&
    DT[REGULAR_TOPIC].sum >= 100
end

def median(array)
  sorted = array.sort
  len = sorted.length
  (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
end

assert_equal 20, median(DT[SPECIAL_TOPIC])
assert (400..500).cover?(median(DT[REGULAR_TOPIC]))
