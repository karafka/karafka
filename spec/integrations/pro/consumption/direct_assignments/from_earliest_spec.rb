# frozen_string_literal: true

# We should be able to get the insights and use them via the API when they are defined
# In Pro despite extra option, should behave same as in OSS when no forced required

setup_karafka

DT[:partitions] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:partitions] << partition
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
    assign(0, 1)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:partitions].size >= 2
end
