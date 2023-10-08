
# frozen_string_literal: true

# Karafka should be able to subscribe and consume messages from as many topics as someone wants
# Here we consume from 100 topics

setup_karafka do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:topics] << messages.metadata.topic
  end
end

draw_routes(create_topics: false) do
  100.times.each do |topic_name|
    topic "t#{topic_name}" do
      consumer Consumer
    end
  end
end

#messages = 100.times.map do |topic_name|
#  { topic: "t#{topic_name}", payload: '1' }
#end
#
#Karafka.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:topics].uniq.size >= DT.topics.size
end

# No specs needed, if not all consumed, will hang
