# frozen_string_literal: true

# Share group (KIP-932) should keep consuming after a no longer used topic has been removed from
# its routes. Records produced to the removed topic afterwards are not consumed, while the topic
# that remained in the share group gets all of them.

setup_karafka

class Consumer1 < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[0] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

class Consumer2 < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[1] << message.raw_payload
      mark_as_accepted(message)
    end
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

start_karafka_and_wait_until(reset_status: true) do
  DT[0].size >= 10 && DT[1].size >= 10
end

# Clear all the routes so later we can subscribe to only one topic
clear_app_draws

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# The default producer is closed with the first stop
producer = WaterDrop::Producer.new do |config|
  config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

[DT.topics[0], DT.topics[1]].each do |topic_name|
  producer.produce_many_sync(DT.uuids(10).map { |payload| { topic: topic_name, payload: payload } })
end

producer.close

# Run a bit longer than needed, so records of the removed topic would show up if consumed
start_karafka_and_wait_until do
  DT[1].size >= 20 && sleep(3)
end

# The removed topic got only the records produced before it was removed from the routes
assert_equal elements1.sort, DT[0].sort
# The remaining topic got everything
assert_equal 20, DT[1].size
assert_equal 20, DT[1].uniq.size
